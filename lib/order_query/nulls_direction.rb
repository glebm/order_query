module OrderQuery
  # Handles nulls :first and :last direction.
  module NullsDirection
    module_function

    DIRECTIONS = [:first, :last].freeze

    def all
      DIRECTIONS
    end

    # @param [:first, :last] direction
    # @return [:first, :last]
    def reverse(direction)
      all[(all.index(direction) + 1) % 2].to_sym
    end

    # @param [:first, :last] direction
    # @raise [ArgumentError]
    # @return [:first, :last]
    def parse!(direction)
      all.include?(direction) && direction or
          raise ArgumentError.new("nulls must be in #{all.map(&:inspect).join(', ')}, is #{direction.inspect}")
    end

    # Returns the default nulls order, based on the given scope's connection adapter name.
    #
    # @param scope [ActiveRecord::Relation]
    # @param dir [:asc, :desc]
    # @return [:first, :last]
    def default(scope, dir)
      case scope.connection_config[:adapter]
        when /mysql|maria|sqlite|sqlserver/i
          (dir == :asc ? :first : :last)
        else
          # Oracle, Postgres
          (dir == :asc ? :last : :first)
      end
    end
  end
end
