module OrderQuery
  module SQL
    class Condition
      attr_reader :condition, :scope

      def initialize(condition, scope)
        @condition = condition
        @scope = scope
      end

      def column_name
        @column_name ||= begin
          sql = condition.options[:sql]
          if sql
            sql.respond_to?(:call) ? sql.call : sql
          else
            connection.quote_table_name(scope.table_name) + '.' + connection.quote_column_name(condition.name)
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
