require 'active_support'
require 'active_record'
require 'order_query/space'
require 'order_query/point'

module OrderQuery
  extend ActiveSupport::Concern

  # @param [ActiveRecord::Relation] scope optional first argument (default: self.class.all)
  # @param [Array<Array<Symbol,String>>, OrderQuery::Spec] order_spec
  # @return [OrderQuery::Point]
  # @example
  #   users = User.active
  #   user  = users.find(42)
  #   next_user = user.seek(users, [:activated_at, :desc], [:id, :desc]).next
  def seek(*spec)
    fst = spec.first
    if fst.nil? || fst.is_a?(ActiveRecord::Relation) || fst.is_a?(ActiveRecord::Base)
      scope = spec.shift
    end
    scope ||= self.class.all
    scope.seek(*spec).at(self)
  end

  module ClassMethods
    # @return [OrderQuery::Space]
    def seek(*spec)
      # allow passing without a splat, as we can easily distinguish
      spec = spec.first if spec.length == 1 && spec.first.first.is_a?(Array)
      Space.new(all, spec)
    end

    #= DSL
    protected
    # @param [Symbol] name
    # @param [Array<Array<Symbol,String>>] order_spec
    # @example
    #   class Post < ActiveRecord::Base
    #     include OrderQuery
    #     order_query :order_home,
    #                [:pinned, [true, false]]
    #                [:published_at, :desc],
    #                [:id, :desc]
    #   end
    #
    #== Scopes
    #   .order_home
    #     #<ActiveRecord::Relation...>
    #   .order_home_reverse
    #     #<ActiveRecord::Relation...>
    #
    #== Class methods
    #   .order_home_at(post)
    #     #<OrderQuery::Point...>
    #   .order_home_space
    #     #<OrderQuery::Space...>
    #
    #== Instance methods
    #   .order_home(scope)
    #     #<OrderQuery::Point...>
    def order_query(name, *spec)
      space_method = :"#{name}_space"
      define_singleton_method space_method, -> {
        seek(*spec)
      }
      scope name, -> {
        send(space_method).scope
      }
      scope "#{name}_reverse", -> {
        send(space_method).scope_reverse
      }
      define_singleton_method "#{name}_at", ->(record) {
        send(space_method).at(record)
      }
      define_method(name) { |scope = nil|
        (scope || self.class).send(space_method).at(self)
      }
    end
  end

  class << self
    attr_accessor :wrap_top_level_or
  end
  # Wrap top-level or with an AND and a redundant condition for performance
  self.wrap_top_level_or = true
end
