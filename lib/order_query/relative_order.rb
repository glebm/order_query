require 'order_query/order_space'
require 'order_query/where_builder'

module OrderQuery

  # Search around a record in a scope
  class RelativeOrder
    attr_reader :record, :order
    delegate :scope, :reverse_scope, to: :order

    # @param [ActiveRecord::Base] record
    # @param [OrderQuery::OrderSpace] order_space
    def initialize(record, order_space)
      @record = record
      @order  = order_space
      @query_builder = WhereBuilder.new record, order_space
    end

    # @return [ActiveRecord::Base]
    def first
      scope.first
    end

    # @return [ActiveRecord::Base]
    def last
      reverse_scope.first
    end

    # @return [Integer]
    def count
      @total ||= scope.count
    end

    # @return [Integer]
    def position
      count - after.count
    end

    # @params [true, false] loop if true, consider last and first as adjacent (unless they are equal)
    # @return [ActiveRecord::Base]
    def next(loop = true)
      unless_record_eq after.first || (first if loop)
    end

    # @return [ActiveRecord::Base]
    def previous(loop = true)
      unless_record_eq before.first || (last if loop)
    end

    # @return [ActiveRecord::Relation]
    def after
      records :after
    end

    # @return [ActiveRecord::Relation]
    def before
      records :before
    end

    # @param [:before, :after] direction
    # @return [ActiveRecord::Relation]
    def records(direction)
      scope             = (direction == :after ? order.scope : order.reverse_scope)
      query, query_args = @query_builder.build_query(direction)
      if query.present?
        scope.where(query, *query_args)
      else
        scope
      end
    end

    protected

    # @param [ActiveRecord::Base] rec
    # @return [ActiveRecord::Base, nil] rec unless rec == @record
    def unless_record_eq(rec)
      rec unless rec == @record
    end
  end
end
