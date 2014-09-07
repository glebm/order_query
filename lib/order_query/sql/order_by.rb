module OrderQuery
  module SQL
    class OrderBy
      # @param [Array<Column>]
      def initialize(columns)
        @columns = columns
      end

      # @return [String]
      def build
        @sql ||= join_order_by_clauses order_by_sql_clauses
      end

      # @return [String]
      def build_reverse
        @reverse_sql ||= join_order_by_clauses order_by_reverse_sql_clauses
      end

      protected

      # @return [Array<String>]
      def order_by_sql_clauses
        @columns.map { |cond| column_clause cond }
      end

      def column_clause(cond)
        dir_sql = sort_direction_sql cond.order
        col_sql = cond.column_name
        if cond.order_enum
          cond.order_enum.map { |v| "#{col_sql}=#{cond.quote v} #{dir_sql}" }.join(', ').freeze
        else
          "#{col_sql} #{dir_sql}".freeze
        end
      end

      SORT_DIRECTIONS = [:asc, :desc].freeze
      # @return [String]
      def sort_direction_sql(direction)
        if SORT_DIRECTIONS.include?(direction)
          direction.to_s.upcase.freeze
        else
          raise ArgumentError.new("sort direction must be in #{SORT_DIRECTIONS.map(&:inspect).join(', ')}, is #{direction.inspect}")
        end
      end

      # @param [Array<String>] clauses
      def join_order_by_clauses(clauses)
        clauses.join(', ').freeze
      end

      # @return [Array<String>]
      def order_by_reverse_sql_clauses
        swap = {'DESC' => 'ASC', 'ASC' => 'DESC'}
        order_by_sql_clauses.map { |s|
          s.gsub(/DESC|ASC/) { |m| swap[m] }
        }
      end
    end
  end
end
