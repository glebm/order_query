require 'active_support'
require 'active_record'
require 'order_query/relative_order'

module OrderQuery
  extend ActiveSupport::Concern

  included do
    scope :order_by_query, ->(order_spec) { OrderSpace.new(self, order_spec).scope }
    scope :reverse_order_by_query, ->(order_spec) { OrderSpace.new(self, order_spec).reverse_scope }
  end

  # @param [ActiveRecord::Relation] scope
  # @param [Array<Array<Symbol,String>>] order_spec
  def relative_order_by_query(scope = self.class.all, order_spec)
    RelativeOrder.new(self, OrderSpace.new(scope, order_spec))
  end

  module ClassMethods
    protected
    # @param [Symbol] name
    # @param [Array<Array<Symbol,String>>] order_spec
    # @example
    #   class Issue
    #     order_query :order_display, [[:created_at, :desc], [:id, :desc]]
    #   end
    #
    #   Issue.order_display #=> <ActiveRecord::Relation#...>
    #   Issue.active.find(31).display_order(Issue.active).next  #=> <Issue#...>
    def order_query(name, order_spec)
      scope name, -> { order_by_query(order_spec) }
      scope :"reverse_#{name}", -> { reverse_order_by_query(order_spec) }
      define_method name do |scope = nil|
        relative_order_by_query scope || self.class.all, order_spec
      end
    end
  end
end
