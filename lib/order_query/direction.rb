module OrderQuery
  # Responsible for handling :asc and :desc
  module Direction
    module_function

    DIRECTIONS = [:asc, :desc].freeze

    def all
      DIRECTIONS
    end

    # @param [:asc, :desc] direction
    # @return [:asc, :desc]
    def reverse(direction)
      all[(all.index(direction) + 1) % 2].to_sym
    end

    # @param [:asc, :desc] direction
    # @raise [ArgumentError]
    # @return [:asc, :desc]
    def parse!(direction)
      all.include?(direction) && direction or
          fail ArgumentError.new("sort direction must be in #{all.map(&:inspect).join(', ')}, is #{direction.inspect}")
    end
  end
end
