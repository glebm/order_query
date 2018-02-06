# frozen_string_literal: true

module OrderQuery
  # All the exceptions that can be raised by order query methods.
  module Errors
    # Raised when a column that OrderQuery assumes to never contain NULLs
    # contains a null.
    class NonNullableColumnIsNullError < RuntimeError
    end
  end
end
