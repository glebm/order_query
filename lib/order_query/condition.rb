require 'order_query/sql/condition'
module OrderQuery
  class Condition
    attr_reader :name, :order, :order_enum, :options, :sql

    # @option spec [String] :unique    Mark the attribute as unique to avoid redundant conditions
    # @option spec [String] :complete  Mark the condition's domain as complete to avoid redundant conditions (only for array conditions)
    def initialize(spec, scope)
      spec    = spec.dup
      options = spec.extract_options!
      @name   = spec[0]
      case spec[1]
        when Array
          @order_enum = spec[1]
          @order      = spec[2] || :desc
        else
          @order = spec[1] || :asc
      end
      @options  = options
      @unique   = if options.key?(:unique)
                    !!options[:unique]
                  else
                    name.to_s == scope.primary_key
                  end
      @complete = if options.key?(:complete)
                    !!options[:complete]
                  else
                    !@order_enum
                  end

      @sql = SQL::Condition.new(self, scope)
    end

    def unique?
      @unique
    end

    def complete?
      @complete
    end

    # @param [Object] value
    # @param [:before, :after] mode
    # @return [Array] valid order values before / after passed (depending on the mode)
    def filter_values(value, mode, strict = true)
      ord = order_enum
      pos = ord.index(value)
      if pos
        dir = order
        if mode == :after && dir == :desc || mode == :before && dir == :asc
          ord.from pos + (strict ? 1 : 0)
        else
          ord.first pos + (strict ? 0 : 1)
        end
      else
        # default to all if current is not in sort order values
        ord
      end
    end

    def inspect
      "Condition(#{@name.inspect}#{" #{@order_enum.inspect}" if @order_enum} #{@order.to_s.upcase} #{'unique ' if @unique}#{@complete ? 'complete' : 'partial' if @order_enum})"
    end
  end
end
