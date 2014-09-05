require 'active_support'
require 'active_record'
require 'order_query/space'
require 'order_query/point'

module OrderQuery
  extend ActiveSupport::Concern

  # @param [ActiveRecord::Relation] scope
  # @param [Array<Array<Symbol,String>>] order_spec
  def order_by(scope = nil, order_spec)
    scope ||= self.class.all
    Point.new(self, Space.new(scope, order_spec))
  end

  module ClassMethods
    def order_by(order_spec)
      Space.new(self, order_spec).scope
    end

    def reverse_order_by(order_spec)
      Space.new(self, order_spec).reverse_scope
    end

    #= DSL
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
      scope name, -> { order_by(order_spec) }
      scope :"reverse_#{name}", -> { reverse_order_by(order_spec) }
      define_method name do |scope = nil|
        order_by scope, order_spec
      end
    end
  end

  class << self
    attr_accessor :wrap_top_level_or
  end
  # Wrap top-level or with an AND and a redundant condition for performance
  self.wrap_top_level_or = true
end
