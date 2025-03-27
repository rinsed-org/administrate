require "rails_helper"
require "spec_helper"
require "support/constant_helpers"
require "administrate/field/belongs_to"
require "administrate/field/string"
require "administrate/field/email"
require "administrate/field/has_many"
require "administrate/field/has_one"
require "administrate/field/number"
require "administrate/field/string"
require "administrate/base_dashboard"
require "administrate/search"

describe Administrate::Search do
  describe "#attribute_types" do
    it "returns attribute types from dashboard instance method if available" do
      class User < ApplicationRecord; end
      scoped_object = User.default_scoped
      dashboard = Administrate::SearchSpecMocks::UserDashboard.new
      search = Administrate::Search.new(scoped_object, dashboard, "test")

      expect(search.send(:attribute_types)).to eq(dashboard.attribute_types)
    ensure
      remove_constants :User
    end

    it "returns ATTRIBUTE_TYPES constant if no instance method available" do
      class User < ApplicationRecord; end
      class BasicDashboard < Administrate::BaseDashboard
        ATTRIBUTE_TYPES = {
          name: Administrate::Field::String
        }.freeze
      end

      scoped_object = User.default_scoped
      search = Administrate::Search.new(scoped_object, BasicDashboard, "test")

      expect(search.send(:attribute_types)).to eq(BasicDashboard::ATTRIBUTE_TYPES)
    ensure
      remove_constants :User, :BasicDashboard
    end

    it "returns empty hash if no attribute types defined" do
      class User < ApplicationRecord; end
      class EmptyDashboard < Administrate::BaseDashboard; end

      scoped_object = User.default_scoped
      search = Administrate::Search.new(scoped_object, EmptyDashboard, "test")

      expect(search.send(:attribute_types)).to eq({})
    ensure
      remove_constants :User, :EmptyDashboard
    end
  end

  describe "#search_attributes" do
    it "delegates to dashboard's search_attributes" do
      class User < ApplicationRecord; end
      scoped_object = User.default_scoped
      dashboard = Administrate::SearchSpecMocks::UserDashboard.new
      search = Administrate::Search.new(scoped_object, dashboard, "test")

      expect(dashboard).to receive(:search_attributes)
      search.send(:search_attributes)
    ensure
      remove_constants :User
    end
  end
end
