require 'order_query/space'
require 'order_query/sql/where'

module OrderQuery
  # Search around a record in an order space
  class Point
    attr_reader :record, :space
    delegate :first, :last, :count, to: :space

    # @param [ActiveRecord::Base] record
    # @param [OrderQuery::Space] space
    def initialize(record, space)
      @record    = record
      @space     = space
      @where_sql = SQL::Where.new(self)
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

    # @return [Integer] counting from 1
    def position
      space.count - after.count
    end

    # @param [true, false] strict choose if the given scope should include or not the record, default not to include it (strict true)
    # @return [ActiveRecord::Relation]
    def after(strict = true)
      side :after, strict
    end

    # @param [true, false] strict choose if the given scope should include or not the record, default not to include it (strict true)
    # @return [ActiveRecord::Relation]
    def before(strict = true)
      side :before, strict
    end

    # @param [:before, :after] side
    # @param [true, false] strict choose if the given scope should include or not the record, default not to include it (strict true)
    # @return [ActiveRecord::Relation]
    def side(side, strict = true)
      query, query_args = @where_sql.build(side, strict)
      scope = if side == :after
                space.scope
              else
                space.scope_reverse
              end
      scope.where(query, *query_args)
    end

    # @param column [Column]
    def value(column)
      v = record.send(column.name)
      if v.nil? && !column.nullable?
        fail "Column #{column.inspect} is NULL on record #{@record.inspect}. Set the `nulls` option to :first or :last."
      end
      v
    end

    def inspect
      "#<OrderQuery::Point @record=#{@record.inspect} @space=#{@space.inspect}>"
    end

    protected

    # @param [ActiveRecord::Base] rec
    # @return [ActiveRecord::Base, nil] rec unless rec == @record
    def unless_record_eq(rec)
      rec unless rec == @record
    end
  end
end
