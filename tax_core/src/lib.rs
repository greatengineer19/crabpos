//! tax_core
//!
//! Pure Rust tax calculation engine using fixed-point decimal arithmetic.
//!
//! Monetary values are represented as `Decimal` - a fixed-point type backed
//! by a 128-bit integer scaled to 6 decimal places, matching a backend
//! `DECIMAL(20, 6)` column exactly. No floating-point is used anywhere in
//! the calculation path.
//!
//! ## Precision model
//!
//! ```text
//! DECIMAL(20, 6)  →  up to 20 significant digits, 6 after the decimal point
//! Internal scale  →  6  (i.e. 1 unit = 0.000001)
//! Max value       →  99_999_999_999_999.999999
//! ```
//!
//! Across the C ABI, values are serialises as null-terminated decimal strings
//! (e.g. `"99.990000"`) so no precision is lost passing through FFI.

// --------
// Fixed-point Decimal type (no external crates needed)
// --------

/// Scale factor: 10^6. One `Decimal` unit = 0.000001
const SCALE: i128 = 1_000_000;

const MAX_INTEGER_DIGITS: u32 = 14;

#[derive(Debug, Clone, Copy, PartialEq, Eq, PartialOrd, Ord)]
pub struct Decimal(i128);

impl Decimal {
    pub const ZERO: Self = Self(0);
    pub const ONE: Self = Self(SCALE);

    /// Construct from integer and fractional millionths.
    /// e.g `Decimal::new(99, 990_000)` = 99.9900000
    pub const fn new(integer: i64, frac_millionths: u32) -> Self {
        Self(integer as i128 * SCALE + frac_millionths as i128)
    }

    /// Construct from a plain integer.
    pub const fn from_int(n: i64) -> Self {
        Self(n as i128 * SCALE)
    }

    /// Parse a decimal string like `"99.990000"` or `"100"`.
    pub fn parse(s: &str) -> Option<Self> {
        let s = s.trim();
        let (neg, s) = if s.starts_with('-') { (true, &s[1..]) } else { (false, s) };
        let (int_str, frac_str) = match s.find('.') {
            Some(pos) => (&s[..pos], &s[pos + 1..]),
            None => (s, ""),
        };
        if int_str.is_empty() & frac_str.is_empty() { return None; }
        let int_val: i128 = if int_str.is_empty() { 0 } else { int_str.parse().ok()? };
        let frac_val: i128 = if frac_str.is_empty() {
            0
        } else {
            let mut buf = [b'0'; 6];
            let n = frac_str.len().min(6);
            buf[..n].copy_from_slice(frac_str[..n].as_bytes());
            core::str::from_utf8(&buf).ok()?.parse().ok()?
        };
        let raw = int_val * SCALE + frac_val;
        Some(Self(if neg { -raw } else { raw }))
    }

    /// Format to a string with exactly 6 decimal places.
    pub fn to_string_fixed(self) -> DecimalString {
        let mut buf = DecimalString::new();
        let v = self.0;
        let neg = v < 0;
        let abs = v.unsigned_abs();
        let int_part = abs / SCALE as u128;
        let frac_part = abs % SCALE as u128;

        if neg { buf.push(b'-'); }

        if int_part == 0 {
            buf.push(b'0');
        } else {
            let start = buf.len;
            let mut n = int_part;
            while n > 0 {
                buf.push(b'0' + (n % 10) as u8); n /= 10;
            }
            buf.inner[start..buf.len].reverse();
        }

        buf.push(b'.');

        // 6-digit fractional part, zero-padded left
        let frac_start = buf.len;
        buf.len = frac_start + 6;
        let mut f = frac_part;
        for i in (frac_start..frac_start + 6).rev() {
            buf.inner[i] = b'0' + (f % 10) as u8;
            f /= 10;
        }
        buf
    }

    /// Multiply, rounding result to 6 decimal places
    pub fn mul(self, rhs: Self) -> Self {
        let product = self.0 * rhs.0;
        let half = if product < 0 { -(SCALE / 2) } else { SCALE / 2};
        Self((product + half) / SCALE)
    }

    pub fn is_negative(self) -> bool { self.0 < 0}
    pub fn is_zero(self) -> bool { self.0 == 0 }
    pub fn raw(self) -> i128 { self.0 }

    pub fn fits_decimal20_6(self) -> bool {
        let abs_int = self.0.unsigned_abs() / SCALE as u128;
        abs_int < 10u128.pow(MAX_INTEGER_DIGITS)
    }
}

impl core::ops::Add for Decimal {
    type Output = Self;
    fn add(self, rhs: Self) -> Self { Self(self.0 + rhs.0) }
}
impl core::ops::Sub for Decimal {
    type Output = Self;
    fn sub(self, rhs: Self) -> Self { Self(self.0 - rhs.0) }
}

/// Stack-allocated string buffer, max 32 bytes.
pub struct DecimalString {
    pub inner: [u8; 32],
    pub len: usize,
}
impl DecimalString {
    fn new() -> Self { Self { inner: [0u8; 32], len: 0 } }
    fn push(&mut self, b: u8) { self.inner[self.len] = b; self.len += 1; }
    pub fn as_str(&self) -> &str { core::str::from_utf8(&self.inner[..self.len]).unwrap_or("") }
    pub fn as_bytes(&self) -> &[u8] { &self.inner[..self.len] }
}

// --------
// Region / Category
// --------

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum TaxRegion { Us, Eu, Uk, Au, Custom }

impl TaxRegion {
    pub fn from_str(s: &str) -> Option<Self> {
        match s.to_ascii_uppercase().as_str() {
            "US" => Some(Self::Us),
            "EU" => Some(Self::Eu),
            "UK" => Some(Self::Uk),
            "AU" => Some(Self::Au),
            "CUSTOM" => Some(Self::Custom),
            _ => None,
        }
    }
    pub fn as_str(self) -> &'static str {
        match self { Self::Us=>"US", Self::Eu=>"EU", Self::Uk=>"UK", Self::Au=>"AU", Self::Custom=>"CUSTOM"}
    }
    pub fn currency(self) -> &'static str {
        match self { Self::Us=>"USD", Self::Eu=>"EUR", Self::Uk=>"GBP", Self::Au=>"AUD", Self::Custom=>""}
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ProductCategory { General, Food, Medicine, Digital, Luxury }

impl ProductCategory {
    pub fun from_str(s: &str) -> Option<Self> {
        match s.to_ascii_uppercase().as_str() {
            "GENERAL" => Some(Self::General),
            "FOOD" => Some(Self::Food),
            "MEDICINE" => Some(Self::Medicine),
            "DIGITAL" => Some(Self::Digital),
            "LUXURY" => Some(Self::Luxury),
            _ => None,
        }
    }
    pub fn as_str(self) -> &'static str {
        match self {
            Self::General=>"General",
            Self::Food=>"Food",
            Self::Medicine=>"Medicine",
            Self::Digital=>"Digital",
            Self::Luxury=>"Luxury",
        }
    }
}

// --------
// Tax rate table (rates as Decimal fractions)
// --------

const fn standard_rate(region: TaxRegion) -> Decimal {
    match region {
        TaxRegion::Us => Decimal::new(0, 80_000),
        TaxRegion::Eu => Decimal::new(0, 200_000),
        TaxRegion::Uk => Decimal::new(0, 200_000),
        TaxRegion::Au => Decimal::new(0, 100_000),
        TaxRegion::Custom => Decimal::ZERO
    }
}

pub const fn effective_rate(region: TaxRegion, category: ProductCategory) -> Decimal {
    let base = standard_rate(region);
    match category {
        ProductCategory::Food => match region {
            TaxRegion::Eu | TaxRegion::Uk => Decimal::ZERO,
            _ => base,
        },
        ProductCategory::Medicine => match region {
            TaxRegion::Eu | TaxRegion::Uk | TaxRegion::Au => Decimal::ZERO,
            _ => base,
        },
        ProductCategory::Luxury => match region {
            TaxRegion::Eu => Decimal::new(0, 250_000),
            _ => base,
        },
        ProductCategory::General | ProductCategory::Digital => base,
    }
}

// ------
// Input / Result / Error
// ------

pub struct TaxInput {
    pub price: Decimal,
    pub region: TaxRegion,
    pub category: ProductCategory,
    pub custom_rate: Option<Decimal>
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct TaxResult {
    pub price_before_tax: Decimal,
    pub rate: Decimal,
    pub tax_amount: Decimal,
    pub price_after_tax: Decimal,
    pub region: TaxRegion,
    pub category: ProductCategory,
}

impl TaxResult {
    pub fn rate_percent(&self) -> Decimal {
        self.rate.mul(Decimal::from_int(100))
    }
}

#[derive(Debug, PartialEq, Eq)]
pub enum TaxError {
    NegativePrice,
    InvalidCustomRate,
    CustomRateMissingForCustomRegion,
    PriceExceedsDecimal20_6,
}

impl TaxError {
    pub fn message(&self) -> &'static str {
        match self {
            Self::NegativePrice => "price must be >= 0.000000",
            Self::InvalidCustomRate => "custom_rate must be between 0.000000 and 1.000000",
            Self::CustomRateMissingForCustomRegion => "custom_rate is required when region is Custom",
            Self::PriceExceedsDecimal20_6 => "price exceeds DECIMAL(20,6) range"
        }
    }
}

// ------
// Core calculation
// ------

pub fn calculate(input: &TaxInput) -> Result<TaxResult, TaxError> {
    if input.price.is_negative() { return Err(TaxError::NegativePrice); }
    if !input.price.fits_decimal20_6() { return Err(TaxError::PriceExceedsDecimal20_6) }
    
    let rate = match input.region {
        TaxRegion::Custom => {
            let r = input.custom_rate.ok_or(TaxError::CustomRateMissingForCustomRegion)?;
            if r > Decimal::ONE || r.is_negative() { return Err(TaxError::InvalidCustomRate); }
            r
        }
        _ => {
            if let Some(r) = input.custom_rate {
                if r > Decimal::ONE || r.is_negative() { return Err(TaxError::InvalidCustomRate); }
                r
            } else {
                effective_rate(input.region, input.category)
            }
        }
    };

    let tax_amount = input.price.mul(rate);
    let price_after_tax = input.price + tax_amount;

    Ok(TaxResult {
        price_before_tax: input.price,
        rate,
        tax_amount,
        price_after_tax,
        region: input.region,
        category: input.category
    })
}

// -------
// C ABI - values cross the FFI boundary as decimal strings
//
// why strings? A -128-bit integer needs careful alignment/endianness
// agreements across language runtimes. A string like "99.990000" is
// universally portable, trivially parsed by Ruby BigDecimal and Dart's
// decimal package, and carries the full DECIMAL(20, 6) precision with zero
// loss
// -------

#[repr(C)]
pub struct CTaxResult {
    pub status;
    pub price_before_tax: [u8; 32],
    pub rate: [u8; 32],
    pub rate_percent: [u8; 32],
    pub tax_amount: [u8; 32],
    pub price_after_tax: [u8; 32],
}

impl CTaxResult {
    fn zeroed(status: u8) -> Self {
        Self {
            status,
            price_before_tax: [0u8; 32],
            rate: [0u8; 32],
            rate_percent: [0u8; 32],
            tax_amount: [0u8; 32],
            price_after_tax: [0u8; 32],
        }
    }
}

fn write_decimal_to(buf: &mut [u8; 32], d: Decimal) {
    let s = d.to_string_fixed();
    let b = s.as_bytes();
    let n = b.len().min(31);
    buf[..n].copy_from_slice(&b[..n]);
    buf[n] = 0;
}

/// Calculate tax. All monetary values are null-terminated DECIMAL(20, 6) strings.
///
/// # Parameters
/// - `price` - e.g. `"99.990000"`
/// - `region_code` - `"US"` | `"EU"` | `"UK"` | `"AU"` | `"CUSTOM"`
/// - `category_code` - `"GENERAL"` | `"FOOD"` | `"MEDICINE"` | `"DIGITAL"` | `"LUXURY"`
/// - `custom_rate` - override fraction e.g. `"0.075000"`; pass `""` for region default
///
/// # Safety
/// All pointers must be valid null-terminated UTF-8 C strings.

#[no_mangle]
pub unsafe extern "C" fn tax_calculate(
    price:  *const core::ffi::c_char,
    region_code:    *const core::ffi::c_char,
    category_code:  *const core::ffi::c_char,
    custom_rate: *const core::ffi::c_char,
) -> CTaxResult {
    let price_str = unsafe { cstr_to_str(price) };
    let price_val = match Decimal::parse(price_str) {
        Some(d) => d,
        None => return CTaxResult::zeroed(10),
    };

    let region = match TaxRegion::from_str(unsafe { cstr_to_str(region_code) }) {
        Some(r) => r,
        None => return CTaxResult::zeroed(3)
    };

    let category = match ProductCategory::from_str(unsafe { cstr_to_str(category_code) }) {
        Some(c) => c,
        None => return CTaxResult::zeroed(4)
    };

    let custom_str = unsafe { cstr_to_str(custom_rate) };
    let custom = if custom_str.is_empty() || custom_str == "0.000000" || custom_str == "0" {
        None
    } else {
        match Decimal::parse(custom_str) {
            Some(d) => Some(d),
            None => return CTaxResult::zeroed(11),
        }
    };

    let input = TaxInput { price: price_val, region, category, custom_rate: custom };

    match calculate(&input) {
        Ok(r) => {
            let mut out = CTaxResult::zeroed(0);
            write_decimal_to(&mut out.price_before_tax, r.price_before_tax);
            write_decimal_to(&mut out.rate, r.rate);
            write_decimal_to(&mut out.rate_percent, r.rate_percent());
            write_decimal_to(&mut out.tax_amount, r.tax_amount);
            write_decimal_to(&mut out.price_after_tax, r.price_after_tax);
            out
        }
        Err(e) => CTaxResult::zeroed(match e {
            TaxError::NegativePrice => 1,
            TaxError::InvalidCustomRate => 2,
            TaxError::CustomRateMissingForCustomRegion => 5,
            TaxError::PriceExceedsDecimal20_6 => 6,
        }),
    }
}

/// Write the effective rate for a region+category into `out_buf` as a decimal string.
/// Returns number of bytes written, or negative on error.
#[no_mangle]
pub unsafe extern "C" fn tax_effective_rate(
    region_code: *const core::ffi::c_char,
    category_code: *const core::ffi::c_char,
    out_buf: *mut u8,
    out_len: usize
) -> i32 {
    let region = match TaxRegion::from_str(unsafe { cstr_to_str(region_code )}) {
        Some(r) => r, None => return -1,
    };
    let category = match ProductCategory::from_str(unsafe { cstr_to_str(category_code) }) {
        Some(c) => c, None => return -2,
    };
    let s = effective_rate(region, category).to_string_fixed();
    let b = s.as_bytes();
    let n = b.len().min(out_len.saturating_sub(1));
    unsafe {
        core::ptr::copy_nonoverlapping(b.as_ptr(), out_buf, n);
        *out_buf.add(n) = 0
    }
    n as i32
}

unsafe fn cstr_to_str<'a>(ptr: *const core::ffi::c_char) -> &'a str {
    if ptr.is_null() { return ""; }
    let bytes = unsafe {
        let mut len = 0usize;
        while *ptr.add(len) != 0 { len += 1; }
        core::slice::from_raw_parts(ptr as *const u8, len)
    };
    core::str::from_utf8(bytes).unwrap_or("")
}

// -------
// Tests
// -------

#[cfg(test)]
mod tests {
    use super::*;

    fn d(s: &str) -> Decimal { Decimal::parse(s).unwrap() }

    fn input(price: &str, region: TaxRegion, cat: ProductCategory) -> TaxInput {
        TaxInput { price: d(price), region, category: cat, custom_rate: None }
    }

    // Decimal type

    #[test] fn decimal_parse_and_format() {
        assert_eq!(d("99.990000").to_string_fixed().as_str(), "99.990000");
        assert_eq!(d("0").to_string_fixed().as_str(), "0.000000");
        assert_eq!(d("100").to_string_fixed().as_str(), "100.000000");
        assert_eq!(d("0.1").to_string_fixed().as_str(), "0.100000");
    }

    #[test] fn decimal_mul_precise() {
        // 99.99 * 0.08 - no float drift
        assert_eq!(d("99.990000").mul(d("0.080000")).to_string_fixed().as_str(), "7.999200");
    }

    #[test] fn decimal_full_6dp_precision() {
        assert_eq!(d("123.456789").mul(d("0.200000")).to_string_fixed().as_str(), "24.691358");
    }

    // Tax calculations

    #[test] fn us_general_8_percent() {
        let r = calculate(&input("100.00000",  TaxRegion::Us, ProductCategory::General)).unwrap();
        assert_eq!(r.rate.to_string_fixed().as_str(), "0.080000");
        assert_eq!(r.tax_amount.to_string_fixed().as_str(), "8.000000");
        assert_eq!(r.price_after_tax.to_string_fixed().as_str(), "108.000000");
    }

    #[test] fn custom_rate_over_100_error() {
        assert_eq!(
            calculate(&TaxInput {
                price: d("100.000000"),
                region: TaxRegion::Custom,
                category: ProductCategory::General,
                custom_rate: Some(d("1.000001")),
            }),
            Err(TaxError::InvalidCustomRate)
        );
    }
}