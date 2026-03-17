# spec/lib/tax_calculator_spec.rb
#
# Unit tests for lib/tax_calculator.rb
#
# These specs stub out the TaxCore FFI module so the compiled Rust shared
# library (libtax_core.dylib / .so) is NOT required at test time.  Every
# public-facing behaviour of TaxCalculator and TaxResult is covered through
# the Ruby layer only.
#
# Run:
#   bundle exec rspec spec/lib/tax_calculator_spec.rb

require "spec_helper"
require "bigdecimal"

# ---------------------------------------------------------------------------
# We must require 'ffi' *before* we can touch FFI::Library — that is what
# defines the module and its methods in the first place.
# Once ffi is loaded we simply redefine the two methods that would otherwise
# try to dlopen the compiled Rust library, turning them into no-ops so the
# shared library never has to exist on disk at test time.
# ---------------------------------------------------------------------------
require "ffi"

module FFI
  module Library
    # Silence ffi_lib so the .dylib/.so path is never resolved.
    def ffi_lib(*_args); end

    # Silence attach_function so no C symbol lookup is attempted.
    def attach_function(*_args); end
  end
end

require_relative "../../lib/tax_calculator"

# ---------------------------------------------------------------------------
# Helper: build a fake CTaxResult-like double with the given decimal strings.
# ---------------------------------------------------------------------------
def build_raw_result(status: 0, price_before_tax: "100.000000",
                     rate: "0.080000", rate_percent: "8.000000",
                     tax_amount: "8.000000", price_after_tax: "108.000000")
  raw = instance_double(TaxCore::CTaxResult)
  allow(raw).to receive(:[]).with(:status).and_return(status)
  {
    price_before_tax: price_before_tax,
    rate:             rate,
    rate_percent:     rate_percent,
    tax_amount:       tax_amount,
    price_after_tax:  price_after_tax,
  }.each do |field, str|
    allow(raw).to receive(:decimal_field).with(field).and_return(str)
  end
  raw
end

# ---------------------------------------------------------------------------
# TAX_STATUS_MESSAGES
# ---------------------------------------------------------------------------
RSpec.describe "TAX_STATUS_MESSAGES" do
  it "maps status 0 to OK" do
    expect(TAX_STATUS_MESSAGES[0]).to eq("OK")
  end

  it "covers all documented status codes" do
    expect(TAX_STATUS_MESSAGES.keys).to match_array([0, 1, 2, 3, 4, 5, 6, 10, 11])
  end
end

# ---------------------------------------------------------------------------
# TaxCalculatorError
# ---------------------------------------------------------------------------
RSpec.describe TaxCalculatorError do
  subject(:error) { described_class.new(1) }

  it "stores the status_code" do
    expect(error.status_code).to eq(1)
  end

  it "uses the message from TAX_STATUS_MESSAGES" do
    expect(error.message).to eq("price must be >= 0.000000")
  end

  it "falls back to a generic message for unknown codes" do
    err = described_class.new(99)
    expect(err.message).to match(/Unknown tax error \(code 99\)/)
  end

  it "inherits from StandardError" do
    expect(error).to be_a(StandardError)
  end
end

# ---------------------------------------------------------------------------
# TaxResult
# ---------------------------------------------------------------------------
RSpec.describe TaxResult do
  let(:result) do
    TaxResult.new(
      price_before_tax: BigDecimal("100.000000"),
      rate:             BigDecimal("0.200000"),
      rate_percent:     BigDecimal("20.000000"),
      tax_amount:       BigDecimal("20.000000"),
      price_after_tax:  BigDecimal("120.000000")
    )
  end

  it "exposes all monetary BigDecimal fields" do
    expect(result.price_before_tax).to eq(BigDecimal("100"))
    expect(result.rate).to eq(BigDecimal("0.2"))
    expect(result.rate_percent).to eq(BigDecimal("20"))
    expect(result.tax_amount).to eq(BigDecimal("20"))
    expect(result.price_after_tax).to eq(BigDecimal("120"))
  end

  describe "#rate_display" do
    it "formats the rate as a percentage string" do
      expect(result.rate_display).to eq("20.000000 %")
    end
  end
end

# ---------------------------------------------------------------------------
# TaxCalculator
# ---------------------------------------------------------------------------
RSpec.describe TaxCalculator do
  subject(:calc) { described_class.new }

  # ---- #calculate -----------------------------------------------------------

  describe "#calculate" do
    context "with valid US / GENERAL inputs (8 %)" do
      let(:raw) { build_raw_result }

      before do
        allow(TaxCore).to receive(:tax_calculate)
          .with("100.000000", "US", "GENERAL", "")
          .and_return(raw)
      end

      it "returns a TaxResult" do
        result = calc.calculate(price: "100.000000")
        expect(result).to be_a(TaxResult)
      end

      it "converts price_before_tax to BigDecimal" do
        result = calc.calculate(price: "100.000000")
        expect(result.price_before_tax).to eq(BigDecimal("100"))
      end

      it "converts rate to BigDecimal fraction" do
        result = calc.calculate(price: "100.000000")
        expect(result.rate).to eq(BigDecimal("0.08"))
      end

      it "converts rate_percent to BigDecimal" do
        result = calc.calculate(price: "100.000000")
        expect(result.rate_percent).to eq(BigDecimal("8"))
      end

      it "computes the correct tax_amount" do
        result = calc.calculate(price: "100.000000")
        expect(result.tax_amount).to eq(BigDecimal("8"))
      end

      it "computes the correct price_after_tax" do
        result = calc.calculate(price: "100.000000")
        expect(result.price_after_tax).to eq(BigDecimal("108"))
      end
    end

    context "with EU / DIGITAL region and category (20 %)" do
      let(:raw) do
        build_raw_result(
          price_before_tax: "99.990000",
          rate:             "0.200000",
          rate_percent:     "20.000000",
          tax_amount:       "19.998000",
          price_after_tax:  "119.988000"
        )
      end

      before do
        allow(TaxCore).to receive(:tax_calculate)
          .with("99.990000", "EU", "DIGITAL", "")
          .and_return(raw)
      end

      it "returns the correct price_after_tax for EU digital goods" do
        result = calc.calculate(price: "99.990000", region: "EU", category: "DIGITAL")
        expect(result.price_after_tax).to eq(BigDecimal("119.988"))
      end

      it "formats the rate display correctly" do
        result = calc.calculate(price: "99.990000", region: "EU", category: "DIGITAL")
        expect(result.rate_display).to eq("20.000000 %")
      end
    end

    context "with a custom_rate override" do
      let(:raw) do
        build_raw_result(
          price_before_tax: "200.000000",
          rate:             "0.075000",
          rate_percent:     "7.500000",
          tax_amount:       "15.000000",
          price_after_tax:  "215.000000"
        )
      end

      before do
        allow(TaxCore).to receive(:tax_calculate)
          .with("200.000000", "CUSTOM", "GENERAL", "0.075000")
          .and_return(raw)
      end

      it "passes the custom_rate string to the Rust library" do
        calc.calculate(
          price: "200.000000",
          region: "CUSTOM",
          category: "GENERAL",
          custom_rate: "0.075000"
        )
        expect(TaxCore).to have_received(:tax_calculate)
          .with("200.000000", "CUSTOM", "GENERAL", "0.075000")
      end

      it "returns the correct price_after_tax for a custom rate" do
        result = calc.calculate(
          price: "200.000000",
          region: "CUSTOM",
          category: "GENERAL",
          custom_rate: "0.075000"
        )
        expect(result.price_after_tax).to eq(BigDecimal("215"))
      end
    end

    context "price coercion" do
      let(:raw) { build_raw_result }

      before do
        allow(TaxCore).to receive(:tax_calculate).and_return(raw)
      end

      it "accepts a BigDecimal price and serialises to a string" do
        calc.calculate(price: BigDecimal("100"))
        expect(TaxCore).to have_received(:tax_calculate)
          .with("100.0", "US", "GENERAL", "")
      end

      it "accepts an Integer price and serialises to a string" do
        calc.calculate(price: 100)
        expect(TaxCore).to have_received(:tax_calculate)
          .with(a_string_matching(/\d+/), "US", "GENERAL", "")
      end
    end

    context "input validation (Ruby layer)" do
      it "raises ArgumentError for an unknown region" do
        expect {
          calc.calculate(price: "10.00", region: "INVALID")
        }.to raise_error(ArgumentError, /Invalid region/)
      end

      it "raises ArgumentError for an unknown category" do
        expect {
          calc.calculate(price: "10.00", category: "INVALID")
        }.to raise_error(ArgumentError, /Invalid category/)
      end

      it "is case-insensitive for region strings" do
        raw = build_raw_result
        allow(TaxCore).to receive(:tax_calculate).and_return(raw)
        expect { calc.calculate(price: "10.00", region: "us") }.not_to raise_error
      end

      it "is case-insensitive for category strings" do
        raw = build_raw_result
        allow(TaxCore).to receive(:tax_calculate).and_return(raw)
        expect { calc.calculate(price: "10.00", category: "general") }.not_to raise_error
      end
    end

    context "when Rust returns a non-zero status code" do
      before do
        raw = instance_double(TaxCore::CTaxResult)
        allow(raw).to receive(:[]).with(:status).and_return(1)
        allow(TaxCore).to receive(:tax_calculate).and_return(raw)
      end

      it "raises TaxCalculatorError with the matching status" do
        expect {
          calc.calculate(price: "-5.000000")
        }.to raise_error(TaxCalculatorError) do |err|
          expect(err.status_code).to eq(1)
          expect(err.message).to eq("price must be >= 0.000000")
        end
      end
    end

    context "when Rust returns status 5 (custom_rate missing for CUSTOM region)" do
      before do
        raw = instance_double(TaxCore::CTaxResult)
        allow(raw).to receive(:[]).with(:status).and_return(5)
        allow(TaxCore).to receive(:tax_calculate).and_return(raw)
      end

      it "raises TaxCalculatorError with status 5" do
        expect {
          calc.calculate(price: "100.000000", region: "CUSTOM", category: "GENERAL")
        }.to raise_error(TaxCalculatorError) do |err|
          expect(err.status_code).to eq(5)
        end
      end
    end
  end

  # ---- #effective_rate ------------------------------------------------------

  describe "#effective_rate" do
    context "when the Rust call succeeds" do
      before do
        buf = instance_double(FFI::MemoryPointer)
        allow(FFI::MemoryPointer).to receive(:new).with(:uint8, 32).and_return(buf)
        allow(buf).to receive(:read_bytes).with(8).and_return("0.200000")
        allow(TaxCore).to receive(:tax_effective_rate).and_return(8)
      end

      it "returns a BigDecimal" do
        result = calc.effective_rate(region: "EU", category: "DIGITAL")
        expect(result).to be_a(BigDecimal)
      end

      it "returns the correct value" do
        result = calc.effective_rate(region: "EU", category: "DIGITAL")
        expect(result).to eq(BigDecimal("0.2"))
      end
    end

    context "when the Rust call returns -1 (unknown region)" do
      before do
        buf = instance_double(FFI::MemoryPointer)
        allow(FFI::MemoryPointer).to receive(:new).with(:uint8, 32).and_return(buf)
        allow(TaxCore).to receive(:tax_effective_rate).and_return(-1)
      end

      it "raises TaxCalculatorError with status 3" do
        expect {
          calc.effective_rate(region: "BOGUS", category: "GENERAL")
        }.to raise_error(TaxCalculatorError) do |err|
          expect(err.status_code).to eq(3)
        end
      end
    end

    context "when the Rust call returns -2 (unknown category)" do
      before do
        buf = instance_double(FFI::MemoryPointer)
        allow(FFI::MemoryPointer).to receive(:new).with(:uint8, 32).and_return(buf)
        allow(TaxCore).to receive(:tax_effective_rate).and_return(-2)
      end

      it "raises TaxCalculatorError with status 4" do
        expect {
          calc.effective_rate(region: "US", category: "BOGUS")
        }.to raise_error(TaxCalculatorError) do |err|
          expect(err.status_code).to eq(4)
        end
      end
    end
  end

  # ---- VALID_REGIONS / VALID_CATEGORIES constants ---------------------------

  describe "constants" do
    it "includes all expected regions" do
      expect(TaxCalculator::VALID_REGIONS).to match_array(%w[US EU UK AU CUSTOM])
    end

    it "includes all expected categories" do
      expect(TaxCalculator::VALID_CATEGORIES)
        .to match_array(%w[GENERAL FOOD MEDICINE DIGITAL LUXURY])
    end
  end
end
