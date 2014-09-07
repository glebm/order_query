require 'order_query/column'
require 'order_query/sql/order_by'
module OrderQuery
  # Order specification and a scope
  class Space
    # @return [Array<OrderQuery::Column>]
    attr_reader :columns

    # @param [ActiveRecord::Relation] base_scope
    # @param [Array<Array<Symbol,String>>, OrderQuery::Spec] order_spec
    def initialize(base_scope, order_spec)
      @base_scope   = base_scope
      @columns   = order_spec.map { |cond_spec| Column.new(cond_spec, base_scope) }
      # add primary key if columns are not unique
      unless @columns.last.unique?
        raise ArgumentError.new('Unique column must be last') if @columns.detect(&:unique?)
        @columns << Column.new([base_scope.primary_key], base_scope)
      end
      @order_by_sql = SQL::OrderBy.new(@columns)
    end

    # @return [Point]
    def at(record)
      Point.new(record, self)
    end

    # @return [ActiveRecord::Relation] scope ordered by columns
    def scope
      @scope ||= @base_scope.order(@order_by_sql.build)
    end

    # @return [ActiveRecord::Relation] scope ordered by columns in reverse
    def scope_reverse
      @scope_reverse ||= @base_scope.order(@order_by_sql.build_reverse)
    end

    # @return [ActiveRecord::Base]
    def first
      scope.first
    end

    # @return [ActiveRecord::Base]
    def last
      scope_reverse.first
    end

    delegate :count, :empty?, to: :@base_scope

    def inspect
      "#<OrderQuery::Space @columns=#{@columns.inspect} @base_scope=#{@base_scope.inspect}>"
    end
  end
end
