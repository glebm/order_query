require 'order_query/space'
require 'order_query/sql/where'

module OrderQuery
  # Search around a record in an order space
  class Point
    attr_reader :record, :space
    delegate :scope, :reverse_scope, to: :space

    # @param [ActiveRecord::Base] record
    # @param [OrderQuery::Space] space
    def initialize(record, space)
      @record    = record
      @space     = space
      @where_sql = SQL::Where.new(self)
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
      query, query_args = @where_sql.build(direction)
      scope = (direction == :after ? space.scope : space.reverse_scope)
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
