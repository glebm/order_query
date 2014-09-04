module OrderQuery
  class OrderCondition
    attr_reader :name, :order, :order_order, :options, :scope

    # @option spec [String] :unique    Mark the attribute as unique to avoid redundant conditions
    # @option spec [String] :complete  Mark the condition's domain as complete to avoid redundant conditions (only for array conditions)
    def initialize(scope, spec)
      spec         = spec.dup
      options      = spec.extract_options!
      @name        = spec[0]
      @order       = spec[1] || :asc
      @order_order = spec[2] || :desc
      @options     = options
      @scope       = scope
      @unique      = if options.key?(:unique)
                       !!options[:unique]
                     else
                       name.to_s == scope.primary_key
                     end
      @complete    = if options.key?(:complete)
                       !!options[:complete]
                     else
                       !list?
                     end
    end

    def unique?
      @unique
    end

    def complete?
      @complete
    end

    # @return [Boolean] whether order is specified as a list of values
    def list?
      order.is_a?(Enumerable)
    end

    # @param [Object] value
    # @param [:before, :after] mode
    # @return [Array] valid order values before / after passed (depending on the mode)
    def filter_values(value, mode, strict = true)
      ord = order
      pos = ord.index(value)
      if pos
        dir = order_order
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

    def col_name_sql
      @col_name_sql ||= begin
        sql = options[:sql]
        if sql
          sql = sql.call if sql.respond_to?(:call)
          sql
        else
          scope.connection.quote_table_name(scope.table_name) + '.' + scope.connection.quote_column_name(name)
        end
      end
    end
  end
end
