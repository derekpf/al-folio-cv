# frozen_string_literal: true

require_relative "test_helper"
require "al_folio_cv"
require "date"

# Regression coverage for `alshedivat/al-folio#3339`: entries that carry a
# single point-in-time `date` instead of a `start_date`/`end_date` pair were
# sorted by `al_cv_sort_by_date` but rendered no date badge at all, and the
# projects template rendered no dates whatsoever.
class PointDateRenderingTest < Minitest::Test
  # Sections that render a date badge from a start/end pair *or* a bare `date`.
  RANGE_TEMPLATES = %w[experience education projects].freeze
  # Sections that only ever render a single point-in-time date.
  POINT_TEMPLATES = %w[awards publications].freeze

  def test_bare_date_renders_a_year_badge
    each_template(RANGE_TEMPLATES) do |name, render|
      assert_equal ["2023"], badges(render.call([{ "date" => "2023-05-01" }])),
                   "#{name}.liquid should render a badge for an entry with only a `date`"
    end
  end

  def test_bare_year_only_date_renders_a_year_badge
    each_template(RANGE_TEMPLATES) do |name, render|
      assert_equal ["2021"], badges(render.call([{ "date" => "2021" }])),
                   "#{name}.liquid should render a badge for a year-only `date`"
    end
  end

  def test_bare_date_is_not_labelled_present
    each_template(RANGE_TEMPLATES) do |name, render|
      # `al_cv_sort_by_date` never treats a standalone `date` as ongoing, so the
      # badge must not claim the entry is still running either.
      refute_includes render.call([{ "date" => "2023-05-01" }]), "Present",
                      "#{name}.liquid should not label a point-in-time `date` as Present"
    end
  end

  def test_yaml_date_objects_render_a_year_badge
    # Unquoted YAML dates in `cv.yml` reach the templates as Ruby Date objects.
    each_template(RANGE_TEMPLATES) do |name, render|
      assert_equal ["2019"], badges(render.call([{ "date" => Date.new(2019, 7, 4) }])),
                   "#{name}.liquid should render a badge for a YAML date object"
    end
  end

  def test_release_date_is_accepted_as_a_point_date
    # `al_cv_sort_by_date` sorts on `releaseDate` too, so rendering follows it.
    each_template(RANGE_TEMPLATES) do |name, render|
      assert_equal ["2016"], badges(render.call([{ "releaseDate" => "2016-11-02" }])),
                   "#{name}.liquid should render a badge for a JSONResume `releaseDate`"
    end
  end

  def test_blank_date_renders_no_badge
    each_template(RANGE_TEMPLATES) do |name, render|
      assert_empty badges(render.call([{ "date" => "   " }])),
                   "#{name}.liquid should not render an empty badge for a blank `date`"
    end
  end

  def test_start_date_still_wins_over_a_bare_date
    each_template(RANGE_TEMPLATES) do |name, render|
      assert_equal ["2020 - Present"], badges(render.call([{ "start_date" => "2020-01-01", "date" => "1999-01-01" }])),
                   "#{name}.liquid should keep rendering the start/end pair when both are present"
    end
  end

  def test_start_end_pair_is_unaffected_by_the_fallback
    each_template(RANGE_TEMPLATES) do |name, render|
      assert_equal ["2015 - 2018"], badges(render.call([{ "start_date" => "2015-03-01", "end_date" => "2018-06-30" }])),
                   "#{name}.liquid should render a closed start/end range unchanged"
      assert_equal ["2015 - 2018"], badges(render.call([{ "startDate" => "2015-03-01", "endDate" => "2018-06-30" }])),
                   "#{name}.liquid should render a closed camelCase range unchanged"
    end
  end

  def test_point_sections_render_a_bare_date
    each_template(POINT_TEMPLATES) do |name, render|
      assert_equal ["2018"], badges(render.call([{ "title" => "Something", "date" => "2018-04-01" }])),
                   "#{name}.liquid should render a badge for an entry with a `date`"
    end
  end

  def test_point_sections_render_no_badge_without_a_date
    each_template(POINT_TEMPLATES) do |name, render|
      assert_empty badges(render.call([{ "title" => "Something" }])),
                   "#{name}.liquid should not render an empty date badge"
    end
  end

  def test_projects_render_their_body_with_and_without_a_date
    # The body is captured once and emitted from both branches, so this also
    # pins down that the captured markup is not HTML-escaped on the way out.
    template = parse("projects")
    entry = { "name" => "Widget", "url" => "https://example.com" }

    [entry, entry.merge("date" => "2024-02-01")].each do |data|
      output = template.render!("entries" => [data])

      assert_includes output, '<h6 class="title font-weight-bold">'
      assert_includes output, '<a href="https://example.com" target="_blank">Widget</a>'
    end
  end

  def test_projects_render_no_date_column_without_a_date
    output = parse("projects").render!("entries" => [{ "name" => "Widget" }])

    assert_empty badges(output), "projects.liquid should not render an empty date badge"
    refute_includes output, "date-column", "projects.liquid should not render a date column for an undated project"
  end

  def test_rendering_agrees_with_al_cv_sort_by_date
    # The two halves must agree: anything the sort filter considers dated has to
    # render a badge, otherwise entries move around for no visible reason.
    entries = [
      { "date" => "2023-05-01" },
      { "releaseDate" => "2016-11-02" },
      { "start_date" => "2020-01-01" },
      { "startDate" => "2015-03-01", "endDate" => "2018-06-30" },
    ]

    each_template(RANGE_TEMPLATES) do |name, render|
      entries.each do |entry|
        start_rank, end_rank = AlFolioCv::DateSorting.bounds(entry)

        refute_equal AlFolioCv::DateSorting::UNDATED_RANK, start_rank, "expected #{entry.inspect} to sort as dated"
        refute_equal AlFolioCv::DateSorting::UNDATED_RANK, end_rank, "expected #{entry.inspect} to sort as dated"
        refute_empty badges(render.call([entry])), "#{name}.liquid should render a badge for #{entry.inspect}"
      end
    end
  end

  private

  def parse(name)
    Liquid::Template.parse(ROOT.join("templates/cv/#{name}.liquid").read)
  end

  def each_template(names)
    names.each do |name|
      template = parse(name)
      yield name, ->(entries) { template.render!("entries" => entries) }
    end
  end

  def badges(output)
    output.scan(%r{<span class="badge[^>]*>(.*?)</span>}m).map { |match| match[0].strip }
  end
end
