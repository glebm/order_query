module OrderQuery
  module SQL
    class Column
      attr_reader :scope, :column

      def initialize(scope, column)
        @scope = scope
        @column = column
      end

      def column_name
        @column_name ||= begin
          sql = column.custom_sql
          if sql
            sql.respond_to?(:call) ? sql.call : sql
          else
            connection.quote_table_name(scope.table_name) + '.' + connection.quote_column_name(column.name)
          end
        end
      end

      def quote(value)
        connection.quote value
      end

      protected

      def connection
        scope.connection
      end
    end
  end
end
