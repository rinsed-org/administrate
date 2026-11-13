require "active_support/core_ext/module/delegation"

module Administrate
  module Field
    class Deferred
      def initialize(deferred_class, options = {})
        @deferred_class = deferred_class
        @options = options
      end

      attr_reader :deferred_class, :options

      def new(*args)
        new_options = args.last.respond_to?(:merge) ? args.pop : {}
        deferred_class.new(*args, options.merge(new_options))
      end

      def ==(other)
        other.respond_to?(:deferred_class) &&
          deferred_class == other.deferred_class &&
          options == other.options
      end

      def getter
        options.fetch(:getter, nil)
      end

      def associative?
        deferred_class.associative?
      end

      def eager_load?
        deferred_class.eager_load?
      end

      def searchable?
        if options.key?(:getter)
          false
        else
          options.fetch(:searchable, deferred_class.searchable?)
        end
      end

      # RINSED: `with_options(search_skip_cast:, search_exact:, search_lower:)`
      # is how a dashboard opts a field out of upstream's unindexable search
      # SQL (see Field::Base). Anything not given falls back to the field
      # class, i.e. to upstream behaviour.
      def search_skip_cast?
        options.fetch(:search_skip_cast, deferred_class.search_skip_cast?)
      end

      def search_exact?
        options.fetch(:search_exact, deferred_class.search_exact?)
      end

      def search_lower?
        options.fetch(:search_lower, deferred_class.search_lower?)
      end
      # END RINSED

      def searchable_fields
        options.fetch(:searchable_fields)
      end

      def sortable?
        options.fetch(:sortable, deferred_class.sortable?)
      end

      def permitted_attribute(attr, opts = {})
        deferred_class.permitted_attribute(attr, options.merge(opts))
      end

      delegate :html_class, to: :deferred_class
    end
  end
end
