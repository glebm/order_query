# frozen_string_literal: true

module OrderExpectations
  # rubocop:disable Metrics/AbcSize

  def expect_next(space, record, next_record, &display)
    point = space.at(record)
    actual = point.next
    failure_message =
      "expected: next(#{display[record]}) == #{display[next_record]}\n" \
      "     got: #{actual ? display[actual] : 'nil'}\n" \
      "     all: #{space.scope.all.map(&display)}\n" \
      "     sql: #{space.at(record).after.limit(1).to_sql}"
    expect(actual ? display[actual] : nil).to eq(display[next_record]),
                                              failure_message
  end

  def expect_prev(space, record, prev_record, &display)
    point = space.at(record)
    actual = point.previous
    failure_message =
      "expected: previous(#{display[record]}) == #{display[prev_record]}\n" \
      "     got: #{actual ? display[actual] : 'nil'}\n" \
      "     all: #{space.scope.all.map(&display)}\n" \
      "     sql: #{space.at(record).before.limit(1).to_sql}"
    expect(actual ? display[actual] : nil).to eq(display[prev_record]),
                                              failure_message
  end

  def expect_order(space, ordered, &display)
    all_actual = space.scope.all.map(&display)
    all_expected = ordered.map(&display)
    failure_message =
      "expected: #{all_expected * ', '}\n"\
      "     got: #{all_actual * ', '}\n"\
      "     sql: #{space.scope.to_sql}"
    expect(all_actual).to eq(all_expected), failure_message

    ordered.each_cons(2) do |record, next_record|
      expect_next space, record, next_record, &display
      expect_prev space, next_record, record, &display
    end
    expect_next space, ordered.last, ordered.first, &display
    expect_prev space, ordered.first, ordered.last, &display
  end

  # rubocop:enable Metrics/AbcSize
end
