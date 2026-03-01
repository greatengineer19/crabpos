//! Flutter bridge for tax_core library.
//!
//! Run `flutter_rust_bridge_codegen generate` to produce the Dart bindings.
//! Generated file: fluuter_app/lib/src/rust/api/tax.dart
//!
//! Monetary values cross the bridge as String (DECIMAL(20, 6) format),
//! matching the backend's DECIMAL(20, 6) column exactly.

use flutter_rust_bridge::frb;
use tax_core::{
    calculate, effective_rate, ProductCategory, TaxError, TaxInput, TaxRegion, Decimal
};

#[frb]
#[derive(Debug, Clone, Copy)]
pub enum Region { Us, Eu, Uk, Au, Custom }

#[frb]
#[derive(Debug, Clone, Copy)]
pub enum Category { General, Food, Medicine, Digital, Luxury }

/// Tax breakdown returned to Dart.
/// All monetary fields are DECIMAL(20,6) strings, e.g. "99.990000".
#[frb]
pub struct TaxBreakdown {
    pub price_before_tax: String, // DECIMAL(20, 6)
    pub rate: String, // fraction e.g. "0.200000"
    pub rate_percent: String, // e.g. "20.000000"
    pub tax_amount: String, // DECIMAL(20,6)
    pub price_after_tax: String, // DECIMAL(20,6)
    pub currency: String,
    pub region_display: String,
    pub category_display: String
}

fn to_core_region(r: Region) -> TaxRegion {
    match r {
        Region::Us => TaxRegion::Us,
        Region::Eu => TaxRegion::Eu,
        Region::Uk => TaxRegion::Uk,
        Region::Au => TaxRegion::Au,
        Region::Custom => TaxRegion::Custom
    }
}

fn to_core_category(c: Category) -> ProductCategory {
    match c {
        Category::General => ProductCategory::General,
        Category::Food => ProductCategory::Food,
        Category::Medicine => ProductCategory::Medicine,
        Category::Digital => ProductCategory::Digital,
        Category::Luxury => ProductCategory::Luxury
    }
}

/// Calculate tax
///
/// `price` - DECIMAL(20,6) string, e.g. "99.9900000"
/// `custom_rate` - optional ovveride fraction, e.g. "0.0750000"; pass "" for default
///
/// Called from dart as:
/// ```dart
/// final result = await calculateTax(
///   price: '99.990000',
///   region: Region.eu,
///   category: Category.digital,
///   customRate: '',
/// );
///
/// ```

#[frb]
pub fn calculate_tax(
    price: String,
    region: Region,
    category: Category,
    custom_rate: String,
) -> Result<TaxBreakdown, String> {
    let core_region = to_core_region(region);
    let core_category = to_core_category(category);

    let price_dec = Decimal::parse(&price)
        .ok_or_else(|| "price is not a valid decimal string".to_string())?;

    let custom = if custom_rate.is_empty() || custom_rate == "0.000000" {
        None
    } else {
        Some(Decimal::parse(&custom_rate)
            .ok_or_else(|| "custom_rate is not a valid decimal string".to_string())?)
    };

    let input = TaxInput {
        price: price_dec,
        region: core_region,
        category: core_category,
        custom_rate: custom,
    };

    calculate(&input)
        .map(|r| TaxBreakdown {
            price_before_tax: r.price_before_tax.to_string_fixed().as_str().to_string(),
            rate: r.rate.to_string_fixed().as_str().to_string(),
            rate_percent: r.rate_percent().to_string_fixed().as_str().to_string(),
            tax_amount: r.tax_amount.to_string_fixed().as_str().to_string(),
            price_after_tax: r.price_after_tax.to_string_fixed().as_str().to_string(),
            currency: core_region.currency().to_string(),
            region_display: core_region.as_str().to_string(),
            category_display: core_category.as_str().to_string(),
        })
        .map_err(|e: TaxError| e.message().to_string())
}

/// Get the effective rate for a region+category as a DECIMAL(20,6) string.
/// e.g. "0.200000" for EU/Digital.
#[frb]
pub fn get_effective_rate(region: Region, category: Category) -> String {
    effective_rate(to_core_region(region), to_core_category(category))
        .to_string_fixed()
        .as_str()
        .to_string()
}