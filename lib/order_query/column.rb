# coding: utf-8
require 'order_query/direction'
require 'order_query/sql/column'
module OrderQuery
  # An order column (sort column)
  class Column
    attr_reader :name, :order_enum, :value, :options
    delegate :column_name, :quote, to: :@sql

    # @option spec [String] :unique    Mark the attribute as unique to avoid redundant columns
    def initialize(spec, scope)
      spec       = spec.dup
      options    = spec.extract_options!
      @name      = spec[0]
      if spec[1].is_a?(Array)
        @order_enum = spec.delete_at(1)
        spec[1] ||= :desc
      end
      @direction = Direction.parse!(spec[1] || :asc)
      @options   = options.reverse_merge(
          unique:   name.to_s == scope.primary_key,
          complete: true
      )
      @unique    = @options[:unique]
      @value     = @options[:value]
      @sql       = SQL::Column.new(self, scope)
    end

    def direction(reverse = false)
      reverse ? Direction.reverse(@direction) : @direction
    end

    def unique?
      @unique
    end

    # @param [Object] value
    # @param [:before, :after] side
    # @return [Array] valid order values before / after passed (depending on the side)
    # @example for [:difficulty, ['Easy', 'Normal', 'Hard']]:
    #  enum_side('Normal', :after) #=> ['Hard']
    #  enum_side('Normal', :after, false) #=> ['Normal', 'Hard']
    def enum_side(value, side, strict = true)
      ord = order_enum
      pos = ord.index(value)
      if pos
        dir = direction
        if side == :after && dir == :desc || side == :before && dir == :asc
          ord.from pos + (strict ? 1 : 0)
        else
          ord.first pos + (strict ? 0 : 1)
        end
      else
        # default to all if current is not in sort order values
        []
      end
    end

    def inspect
      parts = [
          @name,
          (@order_enum.inspect if order_enum),
          ('unique' if @unique),
          (column_name if options[:sql]),
          (value if @value),
          @direction
      ].compact
      "(#{parts.join(' ')})"
    end
  end
end
