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
      group_operators order.map { |term| [where_mode(term, mode), where_eq(term)] }
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
      term = join_terms 'OR', *term_pairs[0]
      rest = term_pairs.from(1)
      if rest.present?
        # nest the remaining pairs recursively, appending them with " AND "
        rest_grouped    = group_operators rest
        rest_grouped[0] = "(#{rest_grouped[0]})" unless rest.length == 1
        join_terms 'AND', term, rest_grouped
      else
        term
      end
    end

    # joins terms with an operator
    # @return [query, parameters]
    def join_terms(op, *terms)
      [terms.map { |t| t.first.presence }.compact.join(" #{op} "),
       terms.map(&:second).reduce(:+) || []]
    end

    EMPTY_FILTER = ['', []]

    # @return [query, params] Unless order attribute is unique, such as id, return ['WHERE value = ?', current value].
    def where_eq(attr)
      if attr.unique?
        EMPTY_FILTER
      else
        [%Q(#{attr.col_name_sql} = ?), [attr_value(attr)]]
      end
    end

    def where_ray(attr, from, strict = true, reverse = false)
      ops = %w(< >)
      ops = ops.reverse if reverse
      op  = {asc: ops[0], desc: ops[1]}[attr.order || :asc]
      ["#{attr.col_name_sql} #{op}#{'=' unless strict} ?", [from]]
    end

    # @param [:before or :after] mode
    # @return [query, params] return query conditions for attribute values before / after the current one
    def where_mode(attr, mode)
      ord   = attr.order
      value = attr_value attr
      if ord.is_a?(Array)
        # ord is an array of sort values, ordered first to last
        pos         = ord.index(value)
        sort_values = if pos
                        dir = attr.order_order
                        if mode == :after && dir == :desc || mode == :before && dir == :asc
                          ord.from(pos + 1)
                        else
                          ord.first(pos)
                        end
                      else
                        # default to all if current is not in sort order values
                        ord
                      end
        # if current not in result set, do not apply filter
        return EMPTY_FILTER unless sort_values.present?
        if sort_values.length == 1
          ["#{attr.col_name_sql} = ?", [sort_values]]
        else
          ["#{attr.col_name_sql} IN (?)", [sort_values]]
        end
      else
        # ord is :asc or :desc
        where_ray(attr, value, true, mode == :after)
      end
    end

    def attr_value(attr)
      record.send attr.name
    end
  end
end
