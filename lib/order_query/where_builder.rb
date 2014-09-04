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
      conditions = order.conditions
      terms = conditions.map { |cond| [where_mode(cond, mode, strict: true), where_eq(cond)] }
      query = group_operators terms
      if self.class.wrap_top_level_or && !terms[0].include?(EMPTY_FILTER)
        join_terms 'AND'.freeze,
                   where_mode(conditions.first, mode, strict: false),
                   ["(#{query[0]})", query[1]]
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
      rest = term_pairs.from(1)
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

    EMPTY_FILTER = [''.freeze, []]

    # @return [query, params] Unless order attribute is unique, such as id, return ['WHERE value = ?', current value].
    def where_eq(cond)
      if cond.unique?
        EMPTY_FILTER
      else
        [%Q(#{cond.col_name_sql} = ?).freeze, [attr_value(cond)]]
      end
    end

    def where_ray(cond, from, mode, strict: true)
      ops = %w(< >)
      ops = ops.reverse if mode == :after
      op  = {asc: ops[0], desc: ops[1]}[cond.order || :asc]
      ["#{cond.col_name_sql} #{op}#{'=' unless strict} ?".freeze, [from]]
    end

    def where_in(cond, values)
      case values.length
        when 0
          EMPTY_FILTER
        when 1
          ["#{cond.col_name_sql} = ?".freeze, [values]]
        else
          ["#{cond.col_name_sql} IN (?)".freeze, [values]]
      end
    end

    # @param [:before or :after] mode
    # @return [query, params] return query conditions for attribute values before / after the current one
    def where_mode(cond, mode, strict: true)
      value = attr_value cond
      if cond.ray?
        where_ray cond, value, mode, strict: strict
      else
        # ord is an array of sort values, ordered first to last
        # if current not in result set, do not apply filter
        where_in cond, cond.values_around(value, mode, strict: strict)
      end
    end

    def attr_value(cond)
      record.send cond.name
    end

    class << self
      attr_accessor :wrap_top_level_or
    end
    self.wrap_top_level_or = true
  end
end
