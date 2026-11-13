require "active_support/core_ext/module/delegation"
require "active_support/core_ext/object/blank"

module Administrate
  class Search
    class Query
      attr_reader :filters, :valid_filters

      def blank?
        terms.blank? && filters.empty?
      end

      def initialize(original_query, valid_filters = nil)
        @original_query = original_query
        @valid_filters = valid_filters
        @filters, @terms = parse_query(original_query)
      end

      def original
        @original_query
      end

      def terms
        @terms.join(" ")
      end

      def to_s
        original
      end

      private

      def filter?(word)
        valid_filters&.any? { |filter| word.match?(/^#{filter}:/) }
      end

      def parse_query(query)
        filters = []
        terms = []
        query.to_s.split.each do |word|
          if filter?(word)
            filters << word
          else
            terms << word
          end
        end
        [filters, terms]
      end
    end

    def initialize(scoped_resource, dashboard, term)
      @dashboard = dashboard
      @scoped_resource = scoped_resource
      @query = Query.new(term, valid_filters.keys)
    end

    def run
      if query.blank?
        @scoped_resource.all
      else
        results = search_results(@scoped_resource)
        filter_results(results)
      end
    end

    def valid_filters
      if @dashboard.class.const_defined?(:COLLECTION_FILTERS)
        @dashboard.class.const_get(:COLLECTION_FILTERS).stringify_keys
      else
        {}
      end
    end

    private

    def apply_filter(filter, filter_param, resources)
      return resources unless filter
      if filter.parameters.size == 1
        filter.call(resources)
      else
        filter.call(resources, filter_param)
      end
    end

    def filter_results(resources)
      query.filters.each do |filter_query|
        filter_name, filter_param = filter_query.split(":")
        filter = valid_filters[filter_name]
        resources = apply_filter(filter, filter_param, resources)
      end
      resources
    end

    def query_template
      search_attributes.map do |attr|
        table_name = query_table_name(attr)
        searchable_fields(attr).map do |field|
          column_name = column_to_query(field)
          # RINSED: upstream hardcodes
          # "LOWER(CAST(#{table_name}.#{column_name} AS CHAR(256))) LIKE ?"
          search_condition(attribute_types[attr], "#{table_name}.#{column_name}")
          # END RINSED
        end.join(" OR ")
      end.join(" OR ")
    end

    # RINSED: upstream's condition wraps the column in LOWER(CAST(...)) and
    # matches with a leading-wildcard LIKE, so it can never use an index and
    # the CAST truncates at 256 chars. Fields can opt out of each part
    # (search_skip_cast / search_lower / search_exact, see Field::Base) so
    # that searching a huge table by an indexed column stays an index lookup.
    # With no options set this returns upstream's condition unchanged.
    #
    # `column` is built only from quoted identifiers that come from the
    # dashboard, never from the search term, which stays a bound `?`.
    def search_condition(attribute_type, column)
      target = column
      target = "CAST(#{target} AS CHAR(256))" unless attribute_type.search_skip_cast?
      target = "LOWER(#{target})" if attribute_type.search_lower?

      operator = attribute_type.search_exact? ? "=" : "LIKE"
      "#{target} #{operator} ?"
    end

    # The bound value has to mirror search_condition: an un-LOWERed column
    # must be compared with the term as typed, and `=` must not get the
    # `%...%` wildcards (they would be matched literally).
    def search_value(attribute_type)
      value = attribute_type.search_lower? ? term.downcase : term
      attribute_type.search_exact? ? value : "%#{value}%"
    end
    # END RINSED

    def searchable_fields(attr)
      return [attr] unless association_search?(attr)

      attribute_types[attr].searchable_fields
    end

    def query_values
      # RINSED: upstream binds the same "%term%" for every condition. Ours
      # differ per attribute (see search_value), and must stay in the same
      # order and count as the `?`s emitted by query_template.
      search_attributes.flat_map do |attr|
        [search_value(attribute_types[attr])] * searchable_fields(attr).count
      end
      # END RINSED
    end

    def search_attributes
      @dashboard.search_attributes
    end

    def search_results(resources)
      resources
        .left_joins(tables_to_join)
        .where(query_template, *query_values)
    end

    def attribute_types
      # RINSED: upstream reads the ATTRIBUTE_TYPES constant, which bypasses
      # `BaseDashboard#attribute_types`. rinsed-web overrides that method to
      # add types at runtime (id/eid, folder_id, versions, http_requests), and
      # `search_attributes` above already goes through it. Reading the
      # constant here means a searchable runtime-added attribute is offered by
      # search_attributes but missing from this hash -> NoMethodError on nil.
      # TODO: upstream this; it is a consistency fix, not Rinsed-specific.
      @dashboard.attribute_types
      # END RINSED
    end

    def query_table_name(attr)
      if association_search?(attr)
        provided_class_name = attribute_types[attr].options[:class_name]
        unquoted_table_name =
          if provided_class_name
            provided_class_name.constantize.table_name
          else
            @scoped_resource.reflect_on_association(attr).klass.table_name
          end
        ActiveRecord::Base.connection.quote_table_name(unquoted_table_name)
      else
        ActiveRecord::Base.connection
          .quote_table_name(@scoped_resource.table_name)
      end
    end

    def column_to_query(attr)
      ActiveRecord::Base.connection.quote_column_name(attr)
    end

    def tables_to_join
      attribute_types.keys.select do |attribute|
        attribute_types[attribute].searchable? && association_search?(attribute)
      end
    end

    def association_search?(attribute)
      attribute_types[attribute].associative?
    end

    def term
      query.terms
    end

    attr_reader :resolver, :query
  end
end
