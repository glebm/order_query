module OrderQuery
  module SQL
    # Build where clause for searching around a record in an order space
    class Where
      attr_reader :point

      # @param [OrderQuery::Point] point
      def initialize(point)
        @point   = point
        @columns = point.space.columns
      end

      # Join column pairs with OR, and nest within each other with AND
      # @param [:before or :after] side
      # @return [query, parameters] WHERE columns matching records strictly before / after this one
      #   sales < 5 OR
      #   sales = 5 AND (
      #     invoice < 3 OR
      #     invoices = 3 AND (
      #       ... ))
      def build(side, strict = true)
        # generate pairs of terms such as sales < 5, sales = 5
        terms = @columns.map.with_index { |col, i|
          be_strict = (i != @columns.size - 1) ? true : strict
          [where_side(col, side, be_strict), where_tie(col)].reject { |x| x == WHERE_IDENTITY }
        }
        # group pairwise with OR, and nest with AND
        query = foldr_terms terms.map { |pair| join_terms 'OR'.freeze, *pair }, 'AND'.freeze
        if ::OrderQuery.wrap_top_level_or
          # wrap in a redundant AND clause for performance
          query = wrap_top_level_or query, terms, side
        end
        query
      end

      protected

      # @param [String] sql_operator SQL operator
      # @return [query, params] terms right-folded with sql_operator
      #   [A, B, C, ...] -> A AND (B AND (C AND ...))
      def foldr_terms(terms, sql_operator)
        foldr_i WHERE_IDENTITY, terms do |a, b, i|
          join_terms sql_operator, a, (i > 1 ? wrap_term_with_parens(b) : b)
        end
      end

      # joins terms with an operator, empty terms are skipped
      # @return [query, parameters]
      def join_terms(op, *terms)
        [terms.map(&:first).reject(&:empty?).join(" #{op} "), terms.map(&:second).reduce([], :+)]
      end

      def wrap_term_with_parens(t)
        ["(#{t[0]})", t[1]]
      end

      # Wrap top level OR clause to help DB with using the index
      # Before:
      #   (sales < 5 OR
      #     (sales = 5 AND ...))
      # After:
      #   (sales <= 5 AND
      #    (sales < 5 OR
      #       (sales = 5 AND ...)))
      # Read more at https://github.com/glebm/order_query/issues/3
      def wrap_top_level_or(query, terms, side)
        top_term_i = terms.index(&:present?)
        if top_term_i && terms[top_term_i].length == 2 && !(col = @columns[top_term_i]).order_enum
          join_terms 'AND'.freeze, where_side(col, side, false), wrap_term_with_parens(query)
        else
          query
        end
      end

      # @return [query, params] tie-breaker unless column is unique
      def where_tie(col)
        if col.unique?
          WHERE_IDENTITY
        else
          where_eq(col)
        end
      end

      # @param [:before or :after] side
      # @return [query, params] return query fragment for column values before / after the current one
      def where_side(col, side, strict = true, value = point.value(col))
        if col.order_enum
          where_in col, col.enum_side(value, side, strict)
        else
          where_ray col, value, side, strict
        end
      end

      def where_in(col, values)
        join_terms 'OR',
                   (values.include?(nil) ? where_eq(col, nil) : WHERE_IDENTITY),
                   case (non_nil_values = values - [nil]).length
                     when 0
                       WHERE_IDENTITY
                     when 1
                       where_eq col, non_nil_values
                     else
                       ["#{col.column_name} IN (?)".freeze, [non_nil_values]]
                   end
      end

      def where_eq(col, value = point.value(col))
        if value.nil?
          ["#{col.column_name} IS NULL", []]
        else
          ["#{col.column_name} = ?", [value]]
        end
      end

      RAY_OP = { asc: '>'.freeze, desc: '<'.freeze }.freeze
      NULLS_ORD = { first: 'IS NOT NULL', last: 'IS NULL' }.freeze
      def where_ray(col, from, mode, strict = true)
        reverse = (mode == :before)
        if from.nil?
          ["#{col.column_name} #{NULLS_ORD[col.nulls_direction(reverse)]}", []]
        else
          ["#{col.column_name} " \
           "#{RAY_OP[col.direction(reverse)]}#{'=' unless strict} ?",
           [from]].tap do |ray|
            if col.nullable? && col.nulls_direction(reverse) == :last
              ray[0] += " OR #{col.column_name} IS NULL"
              ray[0] = "(#{ray[0]})"
            end
          end
        end
      end

      WHERE_IDENTITY = [''.freeze, [].freeze].freeze

      private

      # Inject with index from right to left, turning [a, b, c] into a + (b + c)
      # Passes an index to the block, counting from the right
      # Read more about folds:
      # * http://www.haskell.org/haskellwiki/Fold
      # * http://en.wikipedia.org/wiki/Fold_(higher-order_function)
      def foldr_i(z, xs)
        xs.reverse_each.each_with_index.inject(z) { |b, (a, i)| yield a, b, i }
      end
    end
  end
end
