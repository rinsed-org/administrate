require "rails_helper"
require "administrate/field/deferred"
require "administrate/field/string"

# Specs for the Rinsed-only search options. Kept out of
# spec/lib/fields/deferred_spec.rb so that file stays identical to upstream.
# Ported from the 0.17.0 fork (759ae1ae, dae43672); `search_lower?` had no
# spec there.
describe Administrate::Field::Deferred do
  {
    search_skip_cast?: :search_skip_cast,
    search_exact?: :search_exact,
    search_lower?: :search_lower
  }.each do |predicate, option|
    describe "##{predicate}" do
      context "when given a `#{option}` option" do
        it "returns the value given" do
          enabled = Administrate::Field::Deferred.new(
            double(predicate => false),
            option => true
          )
          disabled = Administrate::Field::Deferred.new(
            double(predicate => true),
            option => false
          )

          expect(enabled.public_send(predicate)).to eq(true)
          expect(disabled.public_send(predicate)).to eq(false)
        end
      end

      context "when not given a `#{option}` option" do
        it "falls back to the default of the deferred class" do
          enabled = Administrate::Field::Deferred.new(
            double(predicate => true)
          )
          disabled = Administrate::Field::Deferred.new(
            double(predicate => false)
          )

          expect(enabled.public_send(predicate)).to eq(true)
          expect(disabled.public_send(predicate)).to eq(false)
        end
      end
    end
  end

  # These defaults are what keeps a dashboard that never opts in on
  # upstream's SQL. Changing one silently changes every admin search.
  describe "defaults inherited from Field::Base" do
    it "reproduces upstream search behaviour" do
      deferred = Administrate::Field::String.with_options({})

      expect(Administrate::Field::String.search_skip_cast?).to eq(false)
      expect(Administrate::Field::String.search_exact?).to eq(false)
      expect(Administrate::Field::String.search_lower?).to eq(true)
      expect(deferred.search_skip_cast?).to eq(false)
      expect(deferred.search_exact?).to eq(false)
      expect(deferred.search_lower?).to eq(true)
    end
  end
end
