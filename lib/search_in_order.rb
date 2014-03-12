require 'active_support'
require 'active_record'
require 'search_in_order/order_def'
require 'search_in_order/search'

module SearchInOrder
  extend ActiveSupport::Concern

  module ClassMethods
    # @return [OrderDef] order definition
    # @example
    #   Issue.in_order([[:id, :desc]]).scope #=> <ActiveRecord::Relation#...>
    def in_order(order)
      OrderDef.new(self, order)
    end

    protected
    # @example
    #   class Issue
    #     search_in_order :display_order, [[:created_at, :desc], [:id, :desc]]
    #   end
    #
    #   Issue.display_order.scope          #=> <ActiveRecord::Relation#...>
    #   Issue.find(31).display_order.next  #=> <Issue#...>
    def search_in_order(name, order)
      define_method(name) do |scope = nil|
        search_in_order(scope || self.class.all, order)
      end

      define_singleton_method(name) do
        in_order order
      end
    end
  end

  # @example
  #  class Issue < ActiveRecord::Base
  #    include SearchInOrder
  #    def self.display_order(scope)
  #     search_in_order scope, [
  #        [:priority, %w(high medium low)],
  #        [:valid_votes_count, :desc, sql: '(votes - suspicious_votes)'],
  #        [:updated_at, :desc],
  #        [:id, :desc]
  #      ]
  #    end
  #    def valid_votes_count
  #      votes - suspicious_votes
  #    end
  #  end
  #  ord = Issue.find(31).display_order(Record.visible)
  #  ord.prev_item
  #  ord.items_after.count
  def search_in_order(scope = self.class.all, order)
    Search.new(self, scope, order)
  end
end
