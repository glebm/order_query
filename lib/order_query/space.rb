# frozen_string_literal: true

require 'order_query/column'
require 'order_query/sql/order_by'
module OrderQuery
  # Order specification and a scope
  class Space
    # @return [Array<OrderQuery::Column>]
    attr_reader :columns
    delegate :count, :empty?, to: :@base_scope

    # @param [ActiveRecord::Relation] base_scope
    # @param [Array<Array<Symbol,String>>] order_spec
    # @see Column#initialize for the order_spec element format.
    def initialize(base_scope, order_spec)
      @base_scope = base_scope
      @columns = order_spec.map do |cond_spec|
        build_column(base_scope, cond_spec)
      end
      # add primary key if columns are not unique
      unless @columns.last.unique?
        if @columns.detect(&:unique?)
          fail ArgumentError, 'Unique column must be last'
        end

        @columns << Column.new(base_scope, base_scope.primary_key)
      end
      @order_by_sql = SQL::OrderBy.new(@columns)
    end

    # @return [Point]
    def at(record)
      Point.new(record, self)
    end

    # @return [ActiveRecord::Relation] scope ordered by columns
    def scope
      @scope ||= @base_scope.order(Arel.sql(@order_by_sql.build))
    end

    # @return [ActiveRecord::Relation] scope ordered by columns in reverse
    def scope_reverse
      @scope_reverse ||= @base_scope
                         .order(Arel.sql(@order_by_sql.build_reverse))
    end

    # @return [ActiveRecord::Base]
    def first
      scope.first
    end

    # @return [ActiveRecord::Base]
    def last
      scope_reverse.first
    end

    def inspect
      "#<OrderQuery::Space @columns=#{@columns.inspect} "\
      "@base_scope=#{@base_scope.inspect}>"
    end

    private

    def build_column(base_scope, cond_spec)
      column_spec = cond_spec.last.is_a?(Hash) ? cond_spec : cond_spec.push({})
      attr_name, *vals_and_or_dir, options = column_spec
      Column.new(base_scope, attr_name, *vals_and_or_dir, **options)
    end
  end
end
