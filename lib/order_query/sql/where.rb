# coding: utf-8
module OrderQuery
  module SQL
    # Build where clause for searching around a record in an order space
    class Where
      attr_reader :point

      # @param [OrderQuery::Point] point
      def initialize(point)
        @point = point
      end

      # @param [:before or :after] side
      # @return [query, parameters] conditions that exclude all elements not before / after the current one
      def build(side)
        # pairs of [x0, y0]
        conditions = point.space.conditions
        parts      = conditions.map { |cond| where_filter_and_tie cond, side }
        query      = combine_query parts
        if ::OrderQuery.wrap_top_level_or
          wrap_top_level_or query, conditions, parts, side
        else
          query
        end
      end

      protected

      # Join condition pairs internally with OR, and nested within each other with AND
      # @param [Array<[filter_query,tie_query]>] term_pairs of query terms [[x0, y0], [x1, y1], ...],
      #                xi, yi are pairs of [query, parameters]
      # @return [query, parameters]
      #   x0 OR
      #   y0 AND (x1 OR
      #           y1 AND (x2 OR
      #                   y2 AND x3))
      #
      # Since x matches order criteria with values that come before / after the current record,
      # and y matches order criteria with values equal to the current record's value (for resolving ties),
      # the resulting condition matches just the elements that come before / after the record
      def combine_query(term_pairs)
        terms = term_pairs.map do |terms|
          join_terms 'OR'.freeze, *terms
        end
        foldr WHERE_IDENTITY, terms do |a, b, ri|
          join_terms 'AND'.freeze, a, ri >= 2 ? wrap_parens(b) : b
        end
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
      def wrap_top_level_or(query, conditions, pairs, side)
        top_pair_idx = pairs.index(&:present?)
        if top_pair_idx &&
            (top_pair = pairs[top_pair_idx]).length == 2 &&
            (top_level_cond = conditions[top_pair_idx]) &&
            (redundant_cond = where_side(top_level_cond, side, false)) != top_pair.first
          join_terms 'AND'.freeze, redundant_cond, wrap_parens(query)
        else
          query
        end
      end

      def wrap_parens(t)
        ["(#{t[0]})", t[1]]
      end

      # joins terms with an operator
      # @return [query, parameters]
      def join_terms(op, *terms)
        [terms.map(&:first).reject(&:blank?).join(" #{op} "), terms.map(&:second).reduce([], :+)]
      end

      # @return [Array<[query,params]>] queries for a side, and a tie-breaker if necessary:
      #   [['sales < ?', 5], ['sales = ?', 5]
      def where_filter_and_tie(cond, side)
        [where_side(cond, side, true), where_tie(cond)].reject { |x| x == WHERE_IDENTITY || x == WHERE_NONE }
      end

      def where_tie(cond)
        if cond.unique?
          WHERE_NONE
        else
          where_eq(cond)
        end
      end

      # @param [:before or :after] side
      # @return [query, params] return query conditions for attribute values before / after the current one
      def where_side(cond, side, strict = true, value = point.value(cond))
        if cond.order_enum
          values = cond.enum_side(value, side, strict)
          if cond.complete? && values.length == cond.order_enum.length
            WHERE_IDENTITY
          else
            where_in cond, values
          end
        else
          where_ray cond, value, side, strict
        end
      end

      def where_in(cond, values)
        case values.length
          when 0
            WHERE_NONE
          when 1
            where_eq cond, values[0]
          else
            ["#{cond.sql.column_name} IN (?)".freeze, [values]]
        end
      end

      def where_eq(cond, value = point.value(cond))
        [%Q(#{cond.sql.column_name} = ?).freeze, [value]]
      end

      def where_ray(cond, from, mode, strict = true)
        ops = %w(< >)
        ops = ops.reverse if mode == :after
        op  = {asc: ops[0], desc: ops[1]}[cond.order || :asc]
        ["#{cond.sql.column_name} #{op}#{'=' unless strict} ?".freeze, [from]]
      end

      WHERE_IDENTITY = [''.freeze, [].freeze].freeze
      WHERE_NONE     = ['∅'.freeze, [].freeze].freeze

      private

      # Turn [a, b, c] into a * (b * c)
      # Read more: http://www.haskell.org/haskellwiki/Fold
      def foldr(z, list, i = 0, &op)
        if list.empty?
          z
        else
          first, *rest = list
          op.call first, foldr(z, rest, &op), rest.length
        end
      end
    end
  end
end
