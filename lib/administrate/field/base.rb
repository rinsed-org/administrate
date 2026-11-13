require_relative "deferred"
require "active_support/core_ext/string/inflections"

module Administrate
  module Field
    class Base
      def self.with_options(options = {})
        Deferred.new(self, options)
      end

      def self.html_class
        field_type.dasherize
      end

      def self.associative?
        self < Associative
      end

      def self.eager_load?
        false
      end

      def self.searchable?
        false
      end

      # RINSED: per-field control over the SQL that Administrate::Search
      # builds. Upstream always emits
      # `LOWER(CAST(col AS CHAR(256))) LIKE '%term%'`, which no index can
      # serve and which truncates long text; on our emails / text messages /
      # support-agent conversations tables that is a full scan per search.
      # The defaults below reproduce upstream's SQL exactly, so a dashboard
      # that does not opt in (via `with_options`) is unaffected.
      def self.search_skip_cast?
        false
      end

      def self.search_exact?
        false
      end

      def self.search_lower?
        true
      end
      # END RINSED

      def self.sortable?
        true
      end

      def self.field_type
        to_s.split("::").last.underscore
      end

      def self.permitted_attribute(attr, _options = nil)
        attr
      end

      def self.partial_prefixes
        @partial_prefixes ||=
          if superclass.respond_to?(:partial_prefixes)
            local_partial_prefixes + superclass.partial_prefixes
          else
            local_partial_prefixes
          end
      end

      def self.local_partial_prefixes
        ["fields/#{field_type}"]
      end

      def initialize(attribute, data, page, options = {})
        @attribute = attribute
        @page = page
        @resource = options.delete(:resource)
        @options = options
        @data = read_value(data)
      end

      def html_class
        self.class.html_class
      end

      def html_controller
        nil
      end

      def name
        attribute.to_s
      end

      def read_value(data)
        if options.key?(:getter)
          if options[:getter].respond_to?(:call)
            options[:getter].call(self)
          else
            resource.try(options[:getter])
          end
        elsif data.nil?
          resource.try(attribute)
        else
          data
        end
      end

      def partial_prefixes
        self.class.partial_prefixes
      end

      def required?
        return false unless resource.class.respond_to?(:validators_on)

        resource.class.validators_on(attribute).any? do |v|
          next false unless v.instance_of?(ActiveRecord::Validations::PresenceValidator)

          options = v.options
          next false if options.include?(:if)
          next false if options.include?(:unless)

          if (on_option = options[:on])
            if on_option == :create && !resource.persisted?
              next true
            end

            if on_option == :update && resource.persisted?
              next true
            end

            next false
          end

          true
        end
      end

      attr_reader :attribute, :data, :options, :page, :resource
    end
  end
end
