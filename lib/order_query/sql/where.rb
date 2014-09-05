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

      # @param [:before or :after] mode
      # @return [query, parameters] conditions that exclude all elements not before / after the current one
      def build(mode)
        conditions = point.space.conditions
        # pairs of [x0, y0]
        pairs = conditions.map { |cond|
          [where_relative(cond, mode, true), (where_eq(cond) unless cond.unique?)].reject { |x|
            x.nil? || x == WHERE_IDENTITY || x == WHERE_NONE
          }.compact
        }
        query = group_operators pairs
        return query unless ::OrderQuery.wrap_top_level_or
        # Wrap top level OR clause for performance, see https://github.com/glebm/order_query/issues/3
        top_pair_idx = pairs.index(&:present?)
        if top_pair_idx &&
            (top_pair = pairs[top_pair_idx]).length == 2 &&
            (top_level_cond = conditions[top_pair_idx]) &&
            (redundant_cond = where_relative(top_level_cond, mode, false)) != top_pair.first
          join_terms 'AND'.freeze, redundant_cond, wrap_parens(query)
        else
          query
        end
      end

      # Join condition pairs internally with OR, and nested within each other with AND
      # @param [Array] term_pairs of query terms [[x0, y0], [x1, y1], ...],
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
      def group_operators(term_pairs)
        # create "x OR y" string
        disjunctive = join_terms 'OR'.freeze, *term_pairs[0]
        rest        = term_pairs.from(1)
        if rest.present?
          # nest the remaining pairs recursively, appending them with " AND "
          rest_grouped = group_operators rest
          join_terms 'AND'.freeze, disjunctive, (rest.length == 1 ? rest_grouped : wrap_parens(rest_grouped))
        else
          disjunctive
        end
      end

      def wrap_parens(t)
        ["(#{t[0]})", t[1]]
      end

      # joins terms with an operator
      # @return [query, parameters]
      def join_terms(op, *terms)
        [terms.map { |t| t.first.presence }.compact.join(" #{op} "),
         terms.map(&:second).reduce(:+) || []]
      end

      # @param [:before or :after] mode
      # @return [query, params] return query conditions for attribute values before / after the current one
      def where_relative(cond, mode, strict = true)
        value = attr_value cond
        if cond.order_enum
          values = cond.filter_values(value, mode, strict)
          if cond.complete? && values.length == cond.order_enum.length
            WHERE_IDENTITY
          else
            where_in cond, values
          end
        else
          where_ray cond, value, mode, strict
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

      def where_eq(cond, value = attr_value(cond))
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

      def attr_value(cond)
        point.record.send cond.name
      end
    end
  end
end
