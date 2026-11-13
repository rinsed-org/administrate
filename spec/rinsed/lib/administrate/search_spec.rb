require "rails_helper"
require "spec_helper"
require "support/constant_helpers"
require "administrate/field/belongs_to"
require "administrate/field/string"
require "administrate/field/email"
require "administrate/field/number"
require "administrate/base_dashboard"
require "administrate/search"

# Specs for the Rinsed-only search behaviour. They live here rather
# than in spec/lib/administrate/search_spec.rb so that file stays identical to
# upstream and never conflicts on a rebase. Ported from the 0.17.0 fork
# (759ae1ae, dae43672).
#
# standard:disable Lint/ConstantDefinitionInBlock
describe Administrate::Search do
  before :all do
    module Administrate
      module RinsedSearchSpecMocks
        class MockRecord < ApplicationRecord
          def self.table_name
            name.demodulize.underscore.pluralize
          end
        end

        class Role < MockRecord; end

        class Foo < MockRecord
          belongs_to :role
        end

        class SkipCastDashboard < Administrate::BaseDashboard
          ATTRIBUTE_TYPES = {
            name: Administrate::Field::String.with_options(
              search_skip_cast: true
            ),
            email: Administrate::Field::Email
          }.freeze
        end

        class ExactDashboard < Administrate::BaseDashboard
          ATTRIBUTE_TYPES = {
            name: Administrate::Field::String.with_options(search_exact: true),
            email: Administrate::Field::Email
          }.freeze
        end

        class SkipCastExactDashboard < Administrate::BaseDashboard
          ATTRIBUTE_TYPES = {
            name: Administrate::Field::String.with_options(
              search_skip_cast: true,
              search_exact: true
            ),
            email: Administrate::Field::Email
          }.freeze
        end

        # The shape rinsed-web's TextMessageDashboard uses for
        # `recipient_phone`: the only combination that yields a bare
        # `col = ?`, i.e. one an ordinary index can serve.
        class IndexLookupDashboard < Administrate::BaseDashboard
          ATTRIBUTE_TYPES = {
            name: Administrate::Field::String.with_options(
              search_skip_cast: true,
              search_exact: true,
              search_lower: false
            ),
            email: Administrate::Field::Email
          }.freeze
        end

        class UnloweredLikeDashboard < Administrate::BaseDashboard
          ATTRIBUTE_TYPES = {
            name: Administrate::Field::String.with_options(
              search_skip_cast: true,
              search_lower: false
            ),
            email: Administrate::Field::Email
          }.freeze
        end

        # Mirrors rinsed-web's BaseDashboard, which adds attribute types at
        # runtime: `id` exists only on the instance, not in the constant.
        class DynamicDashboard < Administrate::BaseDashboard
          ATTRIBUTE_TYPES = {
            name: Administrate::Field::String,
            email: Administrate::Field::Email
          }.freeze

          def attribute_types
            @attribute_types ||= {
              id: Administrate::Field::Number.with_options(searchable: true)
            }.merge(ATTRIBUTE_TYPES)
          end
        end

        class AssociationDashboard < Administrate::BaseDashboard
          ATTRIBUTE_TYPES = {
            role: Administrate::Field::BelongsTo.with_options(
              searchable: true,
              searchable_fields: ["name", "code"],
              search_skip_cast: true,
              search_exact: true,
              search_lower: false
            ),
            title: Administrate::Field::String
          }.freeze
        end
      end
    end
  end

  after :all do
    Administrate.send(:remove_const, :RinsedSearchSpecMocks)
  end

  describe "#run" do
    it "skips CAST when search_skip_cast is true" do
      class User < ApplicationRecord; end
      scoped_object = User.default_scoped
      search = Administrate::Search.new(
        scoped_object,
        Administrate::RinsedSearchSpecMocks::SkipCastDashboard.new,
        "test"
      )
      expected_query = [
        [
          'LOWER("users"."name") LIKE ?',
          'LOWER(CAST("users"."email" AS CHAR(256))) LIKE ?'
        ].join(" OR "),
        "%test%",
        "%test%"
      ]
      expect(scoped_object).to receive(:where).with(*expected_query)

      search.run
    ensure
      remove_constants :User
    end

    it "uses exact match with = when search_exact is true" do
      class User < ApplicationRecord; end
      scoped_object = User.default_scoped
      search = Administrate::Search.new(
        scoped_object,
        Administrate::RinsedSearchSpecMocks::ExactDashboard.new,
        "test"
      )
      expected_query = [
        [
          'LOWER(CAST("users"."name" AS CHAR(256))) = ?',
          'LOWER(CAST("users"."email" AS CHAR(256))) LIKE ?'
        ].join(" OR "),
        "test",
        "%test%"
      ]
      expect(scoped_object).to receive(:where).with(*expected_query)

      search.run
    ensure
      remove_constants :User
    end

    it "combines search_skip_cast and search_exact options" do
      class User < ApplicationRecord; end
      scoped_object = User.default_scoped
      search = Administrate::Search.new(
        scoped_object,
        Administrate::RinsedSearchSpecMocks::SkipCastExactDashboard.new,
        "test"
      )
      expected_query = [
        [
          'LOWER("users"."name") = ?',
          'LOWER(CAST("users"."email" AS CHAR(256))) LIKE ?'
        ].join(" OR "),
        "test",
        "%test%"
      ]
      expect(scoped_object).to receive(:where).with(*expected_query)

      search.run
    ensure
      remove_constants :User
    end

    it "compares the bare column with the term as typed when exact, " \
       "uncast and unlowered" do
      class User < ApplicationRecord; end
      scoped_object = User.default_scoped
      search = Administrate::Search.new(
        scoped_object,
        Administrate::RinsedSearchSpecMocks::IndexLookupDashboard.new,
        "Test"
      )
      expected_query = [
        [
          '"users"."name" = ?',
          'LOWER(CAST("users"."email" AS CHAR(256))) LIKE ?'
        ].join(" OR "),
        "Test",
        "%test%"
      ]
      expect(scoped_object).to receive(:where).with(*expected_query)

      search.run
    ensure
      remove_constants :User
    end

    it "does not downcase the term when search_lower is false" do
      class User < ApplicationRecord; end
      scoped_object = User.default_scoped
      search = Administrate::Search.new(
        scoped_object,
        Administrate::RinsedSearchSpecMocks::UnloweredLikeDashboard.new,
        "Test"
      )
      expected_query = [
        [
          '"users"."name" LIKE ?',
          'LOWER(CAST("users"."email" AS CHAR(256))) LIKE ?'
        ].join(" OR "),
        "%Test%",
        "%test%"
      ]
      expect(scoped_object).to receive(:where).with(*expected_query)

      search.run
    ensure
      remove_constants :User
    end

    it "binds one value per searchable field of an association, " \
       "in template order" do
      scoped_object = Administrate::RinsedSearchSpecMocks::Foo
      search = Administrate::Search.new(
        scoped_object,
        Administrate::RinsedSearchSpecMocks::AssociationDashboard.new,
        "Test"
      )
      allow(scoped_object).to receive(:where)
      allow(scoped_object).to receive(:left_joins).and_return(scoped_object)

      search.run

      expect(scoped_object).to have_received(:where).with(
        '"roles"."name" = ?' \
        ' OR "roles"."code" = ?' \
        ' OR LOWER(CAST("foos"."title" AS CHAR(256))) LIKE ?',
        "Test",
        "Test",
        "%test%"
      )
    end

    it "searches attributes that only exist on the dashboard instance" do
      class User < ApplicationRecord; end
      scoped_object = User.default_scoped
      search = Administrate::Search.new(
        scoped_object,
        Administrate::RinsedSearchSpecMocks::DynamicDashboard.new,
        "test"
      )
      expected_query = [
        [
          'LOWER(CAST("users"."id" AS CHAR(256))) LIKE ?',
          'LOWER(CAST("users"."name" AS CHAR(256))) LIKE ?',
          'LOWER(CAST("users"."email" AS CHAR(256))) LIKE ?'
        ].join(" OR "),
        "%test%",
        "%test%",
        "%test%"
      ]
      expect(scoped_object).to receive(:where).with(*expected_query)

      search.run
    ensure
      remove_constants :User
    end
  end

  describe "#attribute_types" do
    it "reads from the dashboard instance, not the ATTRIBUTE_TYPES constant" do
      class User < ApplicationRecord; end
      dashboard = Administrate::RinsedSearchSpecMocks::DynamicDashboard.new
      search = Administrate::Search.new(User.default_scoped, dashboard, "test")

      expect(search.send(:attribute_types)).to eq(dashboard.attribute_types)
      expect(search.send(:attribute_types)).to include(:id)
    ensure
      remove_constants :User
    end
  end
end
# standard:enable Lint/ConstantDefinitionInBlock
