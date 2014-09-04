module OrderQuery
  # Build where clause for searching around a record in an order space
  class WhereBuilder
    # @return [ActiveRecord::Base]
    attr_reader :record
    # @return [OrderQuery::OrderSpace]
    attr_reader :order

    # @param [ActiveRecord::Base] record
    # @param [OrderQuery::OrderSpace] order_space
    def initialize(record, order_space)
      @order  = order_space
      @record = record
    end

    # @param [:before or :after] mode
    # @return [query, parameters] conditions that exclude all elements not before / after the current one
    def build_query(mode)
      conds = order.conditions
      query = group_operators conds.map { |cond| [where_mode(cond, mode, true), (where_eq(cond) unless cond.unique?)].compact }
      # Wrap top level OR clause for performance, see https://github.com/glebm/order_query/issues/3
      if self.class.wrap_top_level_or && !conds.first.unique?
        join_terms 'AND'.freeze, where_mode(conds.first, mode, false), ["(#{query[0]})", query[1]]
      else
        query
      end
    end

    # Join conditions with operators and parenthesis
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
        rest_grouped    = group_operators rest
        rest_grouped[0] = "(#{rest_grouped[0]})" unless rest.length == 1
        join_terms 'AND'.freeze, disjunctive, rest_grouped
      else
        disjunctive
      end
    end

    # joins terms with an operator
    # @return [query, parameters]
    def join_terms(op, *terms)
      [terms.map { |t| t.first.presence }.compact.join(" #{op} "),
       terms.map(&:second).reduce(:+) || []]
    end

    # @param [:before or :after] mode
    # @return [query, params] return query conditions for attribute values before / after the current one
    def where_mode(cond, mode, strict = true)
      value = attr_value cond
      if cond.list?
        values = cond.filter_values(value, mode, strict)
        if cond.complete? && values.length == cond.order.length
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
          WHERE_IDENTITY
        when 1
          where_eq cond, values[0]
        else
          ["#{cond.col_name_sql} IN (?)".freeze, [values]]
      end
    end

    def where_eq(cond, value = attr_value(cond))
      [%Q(#{cond.col_name_sql} = ?).freeze, [value]]
    end

    def where_ray(cond, from, mode, strict = true)
      ops = %w(< >)
      ops = ops.reverse if mode == :after
      op  = {asc: ops[0], desc: ops[1]}[cond.order || :asc]
      ["#{cond.col_name_sql} #{op}#{'=' unless strict} ?".freeze, [from]]
    end

    WHERE_IDENTITY = [''.freeze, [].freeze].freeze

    def attr_value(cond)
      record.send cond.name
    end

    class << self
      attr_accessor :wrap_top_level_or
    end
    self.wrap_top_level_or = true
  end
end
