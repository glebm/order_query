# frozen_string_literal: true

module OrderQuery
  # Handles nulls :first and :last direction.
  module NullsDirection
    module_function

    DIRECTIONS = %i[first last].freeze

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
        fail ArgumentError,
             "`nulls` must be in #{all.map(&:inspect).join(', ')}, "\
             "is #{direction.inspect}"
    end

    # @param scope [ActiveRecord::Relation]
    # @param dir [:asc, :desc]
    # @return [:first, :last] the default nulls order, based on the given
    #   scope's connection adapter name.
    def default(scope, dir)
      case connection_adapter(scope)
      when /mysql|maria|sqlite|sqlserver/i
        (dir == :asc ? :first : :last)
      else
        # Oracle, Postgres
        (dir == :asc ? :last : :first)
      end
    end

    def connection_adapter(scope)
      if scope.respond_to?(:connection_db_config)
        # Rails >= 6.1.0
        scope.connection_db_config.adapter
      else
        scope.connection_config[:adapter]
      end
    end
  end
end
