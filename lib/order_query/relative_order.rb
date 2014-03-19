require 'order_query/order_space'
module OrderQuery

  class RelativeOrder
    attr_reader :scope, :order, :values, :options

    def initialize(record, scope, order)
      @scope  = scope
      @order  = order.is_a?(OrderSpace) ? order : OrderSpace.new(scope, order)
      @values = Hash.new { |h, key|
        h[key] = record.send(key)
      }
    end

    def first_item
      order.scope.first
    end

    def last_item
      order.scope.last
    end

    def count
      @total ||= scope.count
    end

    def position
      count - items_after.count
    end

    def next_item(loop = true)
      items_after.first || (first_item if loop)
    end

    def prev_item(loop = true)
      items_before.first || (last_item if loop)
    end

    def items_after
      items :after
    end

    def items_before
      items :before
    end

    def items(mode)
      scope             = (mode == :after ? order.scope : order.reverse_scope)
      query, query_args = build_query(mode)
      if query
        scope.where(query, *query_args)
      else
        scope
      end
    end

    protected

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

    # @return [query, params] Unless order attribute is unique, such as id, retrun ['WHERE value = ?', current value]. 
    def where_eq(attr)
      if attr.unique?
        EMPTY_FILTER
      else
        [%Q(#{attr.col_name_sql} = ?), [attr_value(attr)]]
      end
    end

    # @param [:before or :after] mode
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
        ["#{attr.col_name_sql} IN (?)", [sort_values]]
      else
        # ord is :asc or :desc
        op = {before: {asc: '<', desc: '>'}, after: {asc: '>', desc: '<'}}[mode][ord || :asc]
        ["#{attr.col_name_sql} #{op} ?", [value]]
      end
    end

    def attr_value(attr)
      values[attr.name]
    end
  end
end
