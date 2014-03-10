require 'search_in_order/order_def'
module SearchInOrder

  class Search
    attr_reader :scope, :order, :values

    def initialize(record, scope, order)
      @scope  = scope
      @order  = OrderDef.new scope, order
      @values = Hash.new { |h, key|
        h[key] = record.send(key)
      }
    end

    def ordered_scope
      order.scope
    end

    def first_item
      ordered_scope.first
    end

    def last_item
      ordered_scope.last
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
      query, query_args = build_query(mode)
      ordered_scope.where(query, *query_args.reduce(:+))
    end

    protected

    # @param [:before or :after] mode
    def build_query(mode)
      # The next element will be in one of the "groups" of the same values
      join_cond 'OR', order.each_with_index.map { |spec, order_i|
        join_cond 'AND', [
            filter_attr(spec, mode, false),
            * order.first(order_i).reverse.map { |other_spec|
              # unless filter includes everything
              filter_attr(other_spec, mode, true)
            }
        ]
      }
    end

    def filter_attr(spec, mode, eq = false)
      attr, attr_ord = spec.name, spec.order
      value          = values[attr]
      if attr_ord.is_a?(Array)
        attr_eq = "#{spec.col_name_sql} = ?"
        if eq
          [attr_eq, value]
        else
          attr_ord = attr_ord.reverse if mode == :after
          # all up to current
          values   = attr_ord.first(attr_ord.index(value))
          if values.length > 1 && attr_ord.length - 1 == values.length
            ["#{spec.col_name_sql} <> ?", value]
          else
            join_cond('OR', values.map { |value| [attr_eq, value] })
          end
        end
      else
        if eq
          op = '='
        else
          op = attr_ord == :asc ? '>' : '<' if mode == :after
          op = attr_ord == :asc ? '<' : '>' if mode == :before
        end
        ["#{spec.col_name_sql} #{op} ?", value]
      end
    end

    def join_cond(op, pairs)
      query = []
      args  = []
      pairs.each { |p|
        if p[0].present?
          query << p[0]
          args << p[1]
        end
      }
      return [] unless query.present?
      query = query * " #{op} "
      query = "(#{query})" if op == 'OR'
      [query, args]
    end
  end
end
