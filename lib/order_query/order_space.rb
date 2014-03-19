require 'order_query/order_condition'
module OrderQuery
  class OrderSpace
    include Enumerable
    attr_reader :order

    delegate :each, :length, :size, to: :@order

    def initialize(scope, order)
      @scope = scope
      @order = order.map { |line| OrderCondition.new(scope, line) }
    end

    def scope
      @scope.order(order_by_sql)
    end

    def reverse_scope
      @scope.order(order_by_reverse_sql)
    end

    def to_order_by_sql
      @order.map { |spec|
        ord = spec.order
        if ord == :asc || ord == :desc
          "#{spec.col_name_sql} #{ord.to_s.upcase}"
        elsif ord.respond_to?(:map)
          ord.map { |v| "#{spec.col_name_sql}=#{@scope.connection.quote v} #{spec.order_order.to_s.upcase}" } * ', '
        else
          raise "Unknown order #{spec.order.inspect} (#{spec.inspect})"
        end
      }
    end

    def order_by_reverse_sql
      swap = {'DESC' => 'ASC', 'ASC' => 'DESC'}
      to_order_by_sql.map { |s| s.gsub(/DESC|ASC/) { |m| swap[m] }  } * ', '
    end

    def order_by_sql
       to_order_by_sql * ', '
    end
  end
end
