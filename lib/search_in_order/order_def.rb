require 'search_in_order/order_def_item'
module SearchInOrder
  class OrderDef
    include Enumerable
    delegate :each, :length, :size, to: :@order

    def initialize(scope, order)
      @scope = scope
      @order = order.map { |line| OrderDefItem.new(scope, line) }
    end

    def scope
      @scope.order(order_by_sql)
    end

    def order_by_sql
      @order.map { |spec|
        if spec.order == :asc || spec.order == :desc
          "#{spec.col_name_sql} #{spec.order.to_s.upcase}"
        elsif spec.order.is_a?(Array)
          dir = spec.order_order.to_s.upcase
          spec.order.map { |v| "#{spec.col_name_sql}=#{@scope.connection.quote v} #{dir}" } * ', '
        else
          raise "Unknown order #{spec.order.inspect} (#{spec.inspect})"
        end
      } * ', '
    end
  end
end
