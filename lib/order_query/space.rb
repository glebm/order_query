require 'order_query/condition'
require 'order_query/sql/order_by'
module OrderQuery
  # Order specification and a scope
  class Space
    # @return [Array<Condition>]
    attr_reader :conditions
    # @return [ActiveRecord::Relation]
    attr_reader :base_scope

    # @param [ActiveRecord::Relation] scope
    # @param [Array<Array<Symbol,String>>] order_spec
    def initialize(base_scope, order_spec)
      @base_scope   = base_scope
      order_spec    = [order_spec] unless order_spec.empty? || order_spec.first.is_a?(Array)
      @conditions   = order_spec.map { |spec| Condition.new(spec, base_scope) }
      @order_by_sql = SQL::OrderBy.new(self)
    end

    # @return [ActiveRecord::Relation] scope ordered by conditions
    def scope
      @base_scope.order(@order_by_sql.build)
    end

    # @return [ActiveRecord::Relation] scope ordered by conditions in reverse
    def reverse_scope
      @base_scope.order(@order_by_sql.build_reverse)
    end
  end
end
