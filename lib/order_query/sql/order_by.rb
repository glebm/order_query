# frozen_string_literal: true

module OrderQuery
  module SQL
    # Constructs SQL for ORDER BY.
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

      def column_clause_ray(col, reverse = false,
                            with_null_clause = needs_null_sort?(col, reverse))
        clauses = []
        # TODO: use NULLS FIRST/LAST where supported.
        clauses << order_by_nulls_sql(col, reverse) if with_null_clause
        clauses << "#{col.column_name} #{sort_direction_sql(col, reverse)}"
        clauses.join(', ').freeze
      end

      # rubocop:disable Metrics/AbcSize

      def column_clause_enum(col, reverse = false)
        # Collapse booleans enum to `ORDER BY column ASC|DESC`
        return optimize_enum_bools(col, reverse) if optimize_enum_bools?(col)
        if optimize_enum_bools_nil?(col)
          return optimize_enum_bools_nil(col, reverse)
        end
        clauses = []
        with_nulls = false
        if col.order_enum.include?(nil)
          with_nulls = true
        elsif needs_null_sort?(col, reverse)
          clauses << order_by_nulls_sql(col, reverse)
        end
        clauses.concat(col.order_enum.map do |v|
          "#{order_by_value_sql col, v, with_nulls} " \
            "#{sort_direction_sql(col, reverse)}"
        end)
        clauses.join(', ').freeze
      end
      # rubocop:enable Metrics/AbcSize

      def needs_null_sort?(col, reverse,
                           nulls_direction = col.nulls_direction(reverse))
        return false unless col.nullable?
        nulls_direction != col.default_nulls_direction(reverse)
      end

      def order_by_nulls_sql(col, reverse)
        if col.default_nulls_direction !=
           (col.direction == :asc ? :first : :last)
          reverse = !reverse
        end
        "#{col.column_name} IS NULL #{sort_direction_sql(col, reverse)}"
      end

      def order_by_value_sql(col, v, with_nulls = false)
        if with_nulls
          if v.nil?
            "#{col.column_name} IS NULL"
          else
            "#{col.column_name} IS NOT NULL AND " \
               "#{col.column_name}=#{col.quote v}"
          end
        else
          "#{col.column_name}=#{col.quote v}"
        end
      end

      # @return [String]
      def sort_direction_sql(col, reverse = false)
        col.direction(reverse).to_s.upcase.freeze
      end

      # @param [Array<String>] clauses
      def join_order_by_clauses(clauses)
        clauses.join(', ').freeze
      end

      private

      def optimize_enum_bools?(col)
        col.order_enum == [false, true] || col.order_enum == [true, false]
      end

      def optimize_enum_bools(col, reverse)
        column_clause_ray(col, col.order_enum[-1] ^ reverse)
      end

      ENUM_SET_TRUE_FALSE_NIL = Set[false, true, nil]

      def optimize_enum_bools_nil?(col)
        Set.new(col.order_enum) == ENUM_SET_TRUE_FALSE_NIL &&
          !col.order_enum[1].nil?
      end

      def optimize_enum_bools_nil(col, reverse)
        last_bool_true = if col.order_enum[-1].nil?
                           col.order_enum[-2]
                         else
                           col.order_enum[-1]
                         end
        reverse_override = last_bool_true ^ reverse
        with_nulls_sort =
          needs_null_sort?(col, reverse_override, col.nulls_direction(reverse))
        column_clause_ray(col, reverse_override, with_nulls_sort)
      end
    end
  end
end
