# frozen_string_literal: true

require "date"

module AlFolioCv
  # Orders CV entries the way a CV is normally read: most recent first, with
  # ongoing entries at the top.
  #
  # CV data reaches the templates from two sources that disagree on key names
  # (RenderCV uses `start_date`/`end_date`, JSONResume uses
  # `startDate`/`endDate`) and both allow partial dates ("2020", "2020-06"),
  # textual end dates ("present") and entries with no dates at all. Everything
  # here is therefore total: an unrecognised value is treated as "no date"
  # rather than raising.
  module DateSorting
    START_KEYS = %w[start_date startDate].freeze
    END_KEYS = %w[end_date endDate].freeze
    POINT_KEYS = %w[date releaseDate].freeze

    ONGOING_VALUES = %w[present current ongoing now].freeze

    # "2020", "2020-06", "2020-06-01" and the "/" and "." separated variants.
    PARTIAL_DATE = %r{\A(\d{4})(?:[-/.](\d{1,2}))?(?:[-/.](\d{1,2}))?\z}
    # Last-resort fallback for free-form values such as "Fall 2019".
    BARE_YEAR = /(?<!\d)(\d{4})(?!\d)/

    ONGOING_RANK = Float::INFINITY
    UNDATED_RANK = -Float::INFINITY

    module_function

    # Returns a new array ordered by end date descending, then start date
    # descending. Ongoing entries come first, undated entries last, and the
    # original order breaks ties so the sort is stable.
    def sort(entries)
      return entries unless entries.is_a?(Array)

      entries.each_with_index
             .map { |entry, index| [entry, sort_key(entry, index)] }
             .sort_by(&:last)
             .map(&:first)
    end

    def sort_key(entry, index)
      start_rank, end_rank = bounds(entry)
      [-end_rank, -start_rank, index]
    end

    # Resolves an entry to a [start_rank, end_rank] pair of comparable numbers.
    def bounds(entry)
      start_raw = first_present(entry, START_KEYS)
      end_raw = first_present(entry, END_KEYS)
      point_raw = first_present(entry, POINT_KEYS)

      start_rank = parse(start_raw, :start)

      end_rank =
        if ongoing?(end_raw)
          ONGOING_RANK
        elsif end_raw
          parse(end_raw, :end)
        elsif start_rank
          # A start date with no end date means the entry is still running,
          # which is also how the templates render it ("2020 - Present"). A
          # standalone `date` is a point in time and never counts as ongoing.
          ONGOING_RANK
        else
          parse(point_raw, :end)
        end

      [start_rank || parse(point_raw, :start) || UNDATED_RANK, end_rank || UNDATED_RANK]
    end

    def ongoing?(value)
      value.is_a?(String) && ONGOING_VALUES.include?(value.strip.downcase)
    end

    # Turns a date value into an integer of the form YYYYMMDD. Missing
    # components are padded to the start or the end of the period so that a
    # year-only end date ("2020") sorts after a mid-year one ("2020-06").
    def parse(value, boundary)
      case value
      when nil then nil
      when Date, DateTime, Time then compose(value.year, value.month, value.day)
      when Numeric then compose_partial(value.to_i, nil, nil, boundary)
      when String, Symbol
        text = value.to_s.strip
        return nil if text.empty?

        if (match = PARTIAL_DATE.match(text))
          compose_partial(match[1].to_i, match[2]&.to_i, match[3]&.to_i, boundary)
        elsif (match = BARE_YEAR.match(text))
          compose_partial(match[1].to_i, nil, nil, boundary)
        end
        # Anything else (nested hashes, arrays, ...) counts as "no date"; its
        # `to_s` could otherwise contribute a stray four-digit number.
      end
    end

    def compose_partial(year, month, day, boundary)
      if boundary == :end
        compose(year, month || 12, day || 31)
      else
        compose(year, month || 1, day || 1)
      end
    end

    def compose(year, month, day)
      (year.to_i * 10_000) + (clamp(month, 1, 12) * 100) + clamp(day, 1, 31)
    end

    def clamp(value, min, max)
      value = value.to_i
      return min if value < min
      return max if value > max

      value
    end

    # First non-nil, non-blank value among the given keys.
    def first_present(entry, keys)
      keys.each do |key|
        value = lookup(entry, key)
        next if value.nil?
        next if value.is_a?(String) && value.strip.empty?

        return value
      end
      nil
    end

    def lookup(entry, key)
      case entry
      when Hash then entry[key].nil? ? entry[key.to_sym] : entry[key]
      else
        return nil unless entry.respond_to?(:[]) && entry.respond_to?(:key?)

        entry[key]
      end
    end
  end
end
