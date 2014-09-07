require 'order_query/condition'
require 'order_query/sql/order_by'
module OrderQuery
  # Order specification and a scope
  class Space
    # @return [Array<OrderQuery::Condition>]
    attr_reader :conditions

    # @param [ActiveRecord::Relation] base_scope
    # @param [Array<Array<Symbol,String>>, OrderQuery::Spec] order_spec
    def initialize(base_scope, order_spec)
      @base_scope   = base_scope
      @conditions   = order_spec.map { |cond_spec| Condition.new(cond_spec, base_scope) }
      @order_by_sql = SQL::OrderBy.new(@conditions)
    end

    # @return [Point]
    def at(record)
      Point.new(record, self)
    end

    # @return [ActiveRecord::Relation] scope ordered by conditions
    def scope
      @scope ||= @base_scope.order(@order_by_sql.build)
    end

    # @return [ActiveRecord::Relation] scope ordered by conditions in reverse
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
      "#<OrderQuery::Space @conditions=#{@conditions.inspect} @base_scope=#{@base_scope.inspect}>"
    end
  end
end
