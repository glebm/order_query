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
        @reverse_sql ||= join_order_by_clauses order_by_sql_clauses(true)
      end

      protected

      # @return [Array<String>]
      def order_by_sql_clauses(reverse = false)
        @columns.map { |col| column_clause col, reverse }
      end

      def column_clause(col, reverse = false)
        if col.order_enum
          column_clause_enum col, reverse
        else
          column_clause_ray col, reverse
        end
      end

      def column_clause_ray(col, reverse = false)
        "#{col.column_name} #{sort_direction_sql(col, reverse)}".freeze
      end

      def column_clause_enum(col, reverse = false)
        enum = col.order_enum
        # Collapse boolean enum to `ORDER BY column ASC|DESC`
        if enum == [false, true] || enum == [true, false]
          return column_clause_ray col, reverse ^ enum.last
        end
        enum.map { |v|
          "#{order_by_value_sql col, v} #{sort_direction_sql(col, reverse)}"
        }.join(', ').freeze
      end

      def order_by_value_sql(col, v)
        "#{col.column_name}=#{col.quote v}"
      end

      # @return [String]
      def sort_direction_sql(col, reverse = false)
        col.direction(reverse).to_s.upcase.freeze
      end

      # @param [Array<String>] clauses
      def join_order_by_clauses(clauses)
        clauses.join(', ').freeze
      end
    end
  end
end
