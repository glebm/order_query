require 'active_support'
require 'active_record'
require 'search_in_order/order_def'
require 'search_in_order/search'

module SearchInOrder
  extend ActiveSupport::Concern

  module ClassMethods
    # @param [Symbol] name e.g. :display_order
    # @param [Array] order Array of attribute name-order pairs
    # @example
    #  class Issue < ActiveRecord::Base
    #    include SearchInOrder
    #    search_in_order :display_order, [
    #      [:priority, %w(high medium low)],
    #      [:valid_votes_count, :desc, sql: '(votes - suspicious_votes)'],
    #      [:updated_at, :desc],
    #      [:id, :desc]
    #    ]
    #    def valid_votes_count
    #      votes - suspicious_votes
    #    end
    #  end
    #  ord = Issue.find(31).display_order(Record.visible)
    #  ord.prev_item
    #  ord.items_after.count
    def search_in_order(name, order)
      define_method(name) do |scope = nil|
        scope ||= self.class.all
        Search.new(self, scope, order)
      end
      define_singleton_method(name) do
        OrderDef.new(self, order)
      end
    end
  end
end
