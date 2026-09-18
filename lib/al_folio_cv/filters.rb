# frozen_string_literal: true

require_relative "date_sorting"

module AlFolioCv
  # Liquid filters made available to CV templates.
  module Filters
    # Orders CV entries most recent first. Non-array input is passed through
    # unchanged so the filter is safe to chain onto an optional section.
    def al_cv_sort_by_date(input)
      AlFolioCv::DateSorting.sort(input)
    end

    # Formats CV partial dates for compact work-history labels.
    def al_cv_format_date(input)
      AlFolioCv::DateSorting.format(input)
    end
  end
end
