require 'active_support'
require 'active_record'
require 'order_query/relative_order'

module OrderQuery
  extend ActiveSupport::Concern

  included do
    # @return [OrderSpace] order definition
    # @example
    #   Issue.order_query [[:id, :desc]] #=> <ActiveRecord::Relation#...>
    scope :order_by_query, ->(order) { OrderSpace.new(self, order).scope }
    scope :reverse_order_by_query, ->(order) { OrderSpace.new(self, order).reverse_scope }
  end

  def relative_order_by_query(scope = self.class.all, order)
    RelativeOrder.new(self, scope, order)
  end

  module ClassMethods
    protected
    # @example
    #   class Issue
    #     order_query :order_display, [[:created_at, :desc], [:id, :desc]]
    #   end
    #
    #   Issue.order_display #=> <ActiveRecord::Relation#...>
    #   Issue.active.find(31).display_order(Issue.active).next  #=> <Issue#...>
    def order_query(name, order)
      scope name, -> { order_by_query(order) }
      scope :"reverse_#{name}", -> { reverse_order_by_query(order) }
      define_method(name) do |scope = nil|
        scope ||= self.class.all
        relative_order_by_query(scope, order)
      end
    end
  end
end
