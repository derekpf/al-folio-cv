# frozen_string_literal: true

require_relative "test_helper"
require "al_folio_cv"
require "date"

# Regression coverage for issue #3 (port of al-folio PR #3272): work history,
# education and volunteering entries were rendered in source order, so
# volunteering was always appended after work and partial dates never sorted.
class DateSortingTest < Minitest::Test
  def test_orders_most_recent_first
    assert_equal %w[c b a], ids(sort([
      entry("a", "2010-01-01", "2012-01-01"),
      entry("c", "2020-01-01", "2022-01-01"),
      entry("b", "2015-01-01", "2018-01-01"),
    ]))
  end

  def test_ongoing_entries_come_first
    assert_equal %w[ongoing recent old], ids(sort([
      entry("recent", "2018-01-01", "2024-01-01"),
      entry("ongoing", "2005-01-01", nil),
      entry("old", "2000-01-01", "2004-01-01"),
    ]))
  end

  def test_blank_end_date_is_treated_as_ongoing
    assert_equal %w[blank finished], ids(sort([
      entry("finished", "2019-01-01", "2024-01-01"),
      entry("blank", "2001-01-01", "   "),
    ]))
  end

  def test_textual_present_end_dates_are_treated_as_ongoing
    ["present", "Present", "CURRENT", " ongoing ", "now"].each do |value|
      assert_equal %w[ongoing finished], ids(sort([
        entry("finished", "2019-01-01", "2024-01-01"),
        entry("ongoing", "2001-01-01", value),
      ])), "expected #{value.inspect} to be treated as ongoing"
    end
  end

  def test_ongoing_entries_are_ordered_by_start_date
    assert_equal %w[newer older], ids(sort([
      entry("older", "2010-01-01", nil),
      entry("newer", "2021-06-01", nil),
    ]))
  end

  def test_partial_dates_sort_against_full_dates
    assert_equal %w[d c b a], ids(sort([
      entry("a", "2018", "2019"),
      entry("c", "2020-06", "2021-03"),
      entry("b", "2019-01", "2020-01"),
      entry("d", "2021-04-01", "2022-05-06"),
    ]))
  end

  def test_year_only_end_date_covers_the_whole_year
    # "2020" as an end date means the entry ran until the end of 2020, so it
    # must sort above one that ended in March of the same year.
    assert_equal %w[year_only march], ids(sort([
      entry("march", "2015-01-01", "2020-03"),
      entry("year_only", "2015-01-01", "2020"),
    ]))
  end

  def test_mixed_rendercv_and_jsonresume_key_names
    # This is the shape produced by `Experience | concat: Volunteer`.
    entries = [
      { "id" => "volunteer", "startDate" => "2022-01-01", "endDate" => "2023-01-01" },
      { "id" => "work", "start_date" => "2024-01-01", "end_date" => "2025-01-01" },
    ]

    assert_equal %w[work volunteer], ids(sort(entries))
  end

  def test_yaml_date_objects_are_supported
    # Unquoted YAML dates reach the templates as Ruby Date objects.
    entries = [
      { "id" => "older", "start_date" => Date.new(2011, 1, 1), "end_date" => Date.new(2013, 1, 1) },
      { "id" => "newer", "start_date" => Date.new(2014, 1, 1), "end_date" => Date.new(2016, 1, 1) },
    ]

    assert_equal %w[newer older], ids(sort(entries))
  end

  def test_integer_years_are_supported
    entries = [
      { "id" => "older", "start_date" => 1998, "end_date" => 2001 },
      { "id" => "newer", "start_date" => 2002, "end_date" => 2004 },
    ]

    assert_equal %w[newer older], ids(sort(entries))
  end

  def test_undated_entries_sort_last_without_raising
    assert_equal %w[dated undated_a undated_b], ids(sort([
      { "id" => "undated_a" },
      entry("dated", "2019-01-01", "2020-01-01"),
      { "id" => "undated_b", "start_date" => nil, "end_date" => "" },
    ]))
  end

  def test_unparseable_dates_do_not_raise
    entries = [
      entry("good", "2019-01-01", "2020-01-01"),
      entry("garbage", "not a date", %w[also not a date]),
      { "id" => "nested", "start_date" => { "year" => 2020 } },
    ]

    assert_equal %w[good garbage nested], ids(sort(entries))
  end

  def test_free_form_dates_fall_back_to_the_year
    assert_equal %w[fall2019 spring2017], ids(sort([
      entry("spring2017", "Spring 2017", "Summer 2018"),
      entry("fall2019", "Fall 2019", "Winter 2020"),
    ]))
  end

  def test_point_dates_are_not_treated_as_ongoing
    # RenderCV entries may carry a single `date` instead of a start/end pair.
    assert_equal %w[ongoing point], ids(sort([
      { "id" => "point", "date" => "2023-01-01" },
      entry("ongoing", "2012-01-01", nil),
    ]))
  end

  def test_sort_is_stable_for_equal_dates
    entries = ("a".."f").map { |id| entry(id, "2020-01-01", "2021-01-01") }

    assert_equal %w[a b c d e f], ids(sort(entries))
  end

  def test_input_is_not_mutated
    entries = [entry("a", "2010-01-01", "2011-01-01"), entry("b", "2020-01-01", "2021-01-01")]
    original = entries.dup

    sort(entries)

    assert_equal original, entries
  end

  def test_non_array_input_is_passed_through
    assert_nil AlFolioCv::DateSorting.sort(nil)
    assert_equal "", AlFolioCv::DateSorting.sort("")
  end

  def test_filter_is_registered_with_liquid
    entries = [entry("older", "2010-01-01", "2011-01-01"), entry("newer", "2020-01-01", "2021-01-01")]
    template = Liquid::Template.parse("{% assign sorted = entries | al_cv_sort_by_date %}{% for e in sorted %}{{ e.id }},{% endfor %}")

    assert_equal "newer,older,", template.render("entries" => entries)
  end

  def test_formats_compact_month_year_dates
    assert_equal "Apr. 2026", AlFolioCv::DateSorting.format("2026-04")
    assert_equal "Aug. 2026", AlFolioCv::DateSorting.format("2026-08-01")
    assert_equal "Present", AlFolioCv::DateSorting.format("present")
    assert_equal "2026", AlFolioCv::DateSorting.format("2026")
  end

  def test_date_format_filter_is_registered_with_liquid
    template = Liquid::Template.parse("{{ value | al_cv_format_date }}")

    assert_equal "Aug. 2025", template.render("value" => "2025-08")
  end

  def test_render_template_sorts_experience_and_education
    render = ROOT.join("templates/cv/render.liquid").read

    assert_includes render, "{% assign combined_experience = exp | concat: vol | al_cv_sort_by_date %}"
    assert_includes render, "{% assign combined_experience = work | concat: vol | al_cv_sort_by_date %}"
    assert_includes render, "{% assign entries = section_entries | al_cv_sort_by_date %}"
    assert_includes render, "{% assign entries = site.data.resume.education | al_cv_sort_by_date %}"
  end

  private

  def sort(entries)
    AlFolioCv::DateSorting.sort(entries)
  end

  def entry(id, start_date, end_date)
    { "id" => id, "start_date" => start_date, "end_date" => end_date }
  end

  def ids(entries)
    entries.map { |entry| entry["id"] }
  end
end
