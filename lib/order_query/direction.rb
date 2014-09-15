module OrderQuery
  # Responsible for handling :asc and :desc
  module Direction
    extend self

    DIRECTIONS   = [:asc, :desc].freeze
    DIRECTIONS_S = DIRECTIONS.map { |d| d.to_s.freeze }.freeze

    def all
      DIRECTIONS
    end

    # @param [:asc, :desc] direction
    # @return [:asc, :desc]
    def reverse(direction)
      all[(all.index(direction) + 1) % 2].to_sym
    end

    # @param [:asc, :desc, String] direction
    # @raise [ArgumentError]
    # @return [:asc, :desc]
    def parse!(direction)
      if direction.is_a?(Symbol)
        direction if DIRECTIONS.include?(direction)
      else
        direction = direction.to_s.downcase
        direction.to_sym if DIRECTIONS_S.include?(direction)
      end or
          raise ArgumentError.new("sort direction must be in #{all.map(&:inspect).join(', ')}, is #{direction.inspect}")
    end
  end
end
