# lib/tax_calculator.rb
#
# Ruby FFI binding to the compiled Rust tax-core shared library.
# Monetary values are exchanged as BigDecimal strings matching DECIMAL(20,6).
#
# Preqrequisites:
# gem install ffi
# require 'bigdecimal' (stdlib, always available)
#
# Build the library:
# cargo build --release
# # => target/release/libtax_core.so (Linux)
# # => target/release/libtax_core.dylib (macOS)
#
# Usage:
# calc = TaxCalculator.new
# result = calc.calculate(price: "99.9900000", region: "EU", category: "DIGITAL")
# result.price_after_tax # => BigDecimal("119.9900000")
# result.rate_percent # => BigDecimal("20.000000")
# result.tax_amount # => BigDecimal("19.998000")

require "ffi"
require "bigdecimal"

module TaxCore
	extend FFI::Library

	lib_path = ENV["TAX_CORE_LIB"] ||
							File.expand_path(
							"../../../tax-calculator/targer/release/#{FFI.map_library_name("tax_core")}",
							__FILE__
							)

	ffi_lib lib_path

	# ------------------------------
	# C struct: CTaxResult
	# Mirror #[repr(C)] struct CTaxResult in tax-core/src/lib.rs.
	# All monetary fields are 32-byte null-terminated decimal strings.
	#
	# struct CTaxResult {
	#   uint8_t status;
	#   char price_before_tax[32]
	#   char rate[32];
	#   char rate_percent[32];
	#   char tax_amount[32];
	#   char price_after_tax[32];
	# }
	# ------------------------------

	class CTaxResult < FFI::Struct
		layout \
			:status,    :uint8,
			:_pad,  [:uint8, 7],
			:price_before_tax, [:uint8, 32],
			:rate, [:uint8, 32],
			:rate_percent, [:uint8, 32],
			:tax_amount, [:uint8, 32],
			:price_after_tax, [:uint8, 32]

		# Read a decimal string field and strip the NUL terminator.
		def decimal_field(name)
			bytes = self[name].to_a
			nul = bytes.index(0) || bytes.size
			bytes[0...nul].pack("C*")
		end
	end

	# tax_calculate(price, region_code, category_code, custom_rate) -> CTaxResult
	attach_function :tax_calculate,
									[:string, :string, :string, :string],
									CTaxResult.by_value

	# tax_effective_rate(region_code, category_code, out_buf, out_len) -> int32
	attach_function :tax_effective_rate,
									[:string, :string, :pointer, :size_t],
									:int32
end

# ------
# Status codes returned by the Rust library
# ------
TAX_STATUS_MESSAGES = {
	0  => "OK",
  1  => "price must be >= 0.000000",
  2  => "custom_rate must be between 0.000000 and 1.000000",
  3  => "Unknown region code",
  4  => "Unknown category code",
  5  => "custom_rate is required when region is CUSTOM",
  6  => "price exceeds DECIMAL(20,6) range",
  10 => "price is not a valid decimal string",
  11 => "custom_rate is not a valid decimal string",
}.freeze

class TaxCalculatorError < StandardError
	attr_reader :status_code

	def initialize(code)
		@status_code = code
		super(TAX_STATUS_MESSAGES.fetch(code, "Unknown tax error (code #{code})"))
	end
end

# ------
# Result value object - all monetary fields are BigDecimal
# ------
TaxResult = Data.define(
	:price_before_tax,
	:rate,
	:rate_percent,
	:tax_amount,
	:price_after_tax
) do
	# Convenience: formatted percentage string for display
	def rate_display = "#{rate_percent.to_s("F")} %"
end

# ------
# Main calculator - wraps the Rust FFI calls with a clean Ruby API
# ------
class TaxCalculator
	VALID_REGIONS = %w[US EU UK AU CUSTOM].freeze
	VALID_CATEGORIES = %w[GENERAL FOOD MEDICINE DIGITAL LUXURY].freeze

	# Calcualte tax for a product.
	#
	# @param price	[String, BigDecimal, Numeric]
	#								Pre-tax price in DECIMAL(20,6) format.
	#								Pass a String for exact representation: "99.9900000"
	#								BigDecimal and Numeric are also accepted and converted.
	#
	# @param region		[String]	"US" | "EU" | "UK" | "AU" | "CUSTOM"
	# @param category	[String]	"GENERAL" | "FOOD" | "MEDICINE" | "DIGITAL" | "LUXURY"
	# @param custom_rate [String, BigDecimal, nil]
	#											Override tax rate as a fraction, e.g. "0.075000" = 7.5%.
	#											Pass nil or omit to use the region/category default.
	#
	# @return [TaxResult]
	# @raise [TaxCalculatorError, ArgumentError]

	def calculate(price:, region: "US", category: "GENERAL", custom_rate: nil)
		region_s = region.to_s.upcase
		category_s = category.to_s.upcase
		price_s = decimal_string(price)
		custom_s = custom_rate ? decimal_string(custom_rate) : ""

		validate!(region_s, category_s)

		raw = TaxCore.tax_calculate(price_s, region_s, category_s, custom_s)

		raise TaxCalculatorError.new(raw[:status]) unless raw[:status] == 0

		TaxResult.new(
			price_before_tax: BigDecimal(raw.decimal_field(:price_before_tax)),
			rate: BigDecimal(raw.decimal_field(:rate)),
			rate_percent: BigDecimal(raw.decimal_field(:rate_percent)),
			tax_amount: BigDecimal(raw.decimal_field(:tax_amount)),
			price_after_tax: BigDecimal(raw.decimal_field(:price_after_tax))
		)
	end

	# Return the effective rate for a region+category as a BigDecimal fraction.
	# Useful for showing the rate in the UI before completing a calculation.
	#
	# @return [BigDecimal] e.g. BigDecimal("0.200000") for EU/Digital
	def effective_rate(region: "US", category: "GENERAL")
		buf = FFI::MemoryPointer.new(:uint8, 32)
		n = TaxCore.tax_effective_rate(region.to_s.upcase, category.to_s.upcase, buf, 32)
		raise TaxCalculatorError.new(3) if n == -1
		raise TaxCalculatorError.new(4) if n == -2
		BigDecimal(buf.read_bytes(n))
	end

	private

	# Normalise any numeric atype to a DECIMAL(20,6) string.
	# Strings are passed through as-is (you own the precision).
	def decimal_string(value)
		case value
		when String then value
		when BigDecimal then value.to_s("F")
		when Numeric then BigDecimal(value.to_s).to_s("F")
		else value.to_s
		end
	end

	def validate!(region, category)
		unless VALID_REGIONS.include?(region)
			raise ArgumentError, "Invalid region '#{region}'. Valid: #{VALID_REGIONS.join(", ")}"
		end
		unless VALID_CATEGORIES.include?(category)
			raise ArgumentError, "Invalid category '#{category}'. Valid: #{VALID_CATEGORIES.join(", ")}"
		end
	end
end

# ======
# Example Rails usage
# ======
#
# # config/initializers/tax_calculator.rb
# TAX_CALC = TaxCalculator.new
#
# # app/models/order_item.rb
# class OrderItem < ApplicationRecord
#   # price is stored as DECIMAL(20,6) in the DB
#
#   def tax_breakdown(region:)
#     TAX_CALC.calculate(
#       price:    price,           # BigDecimal from ActiveRecord
#       region:   region,          # e.g. current_user.tax_region
#       category: product.tax_cat  # e.g. "DIGITAL"
#     )
#   end
#
#   def total_price(region:)
#     tax_breakdown(region: region).price_after_tax
#   end
# end
#
# # In the controller / serializer:
# breakdown = item.tax_breakdown(region: "EU")
# {
#   price:       breakdown.price_before_tax,  # BigDecimal → JSON number
#   tax_rate:    breakdown.rate_display,       # "20.000000 %"
#   tax_amount:  breakdown.tax_amount,
#   total:       breakdown.price_after_tax
# }
