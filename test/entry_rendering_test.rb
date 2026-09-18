# frozen_string_literal: true

require_relative "test_helper"
require "al_folio_cv"

# Regression coverage for issue #2 (port of al-folio PR #3537): `capture` keeps
# the whitespace around its body, so the `!= ''` guards in the entry templates
# never matched. An entry without an end date lost its "Present" label, an
# entry without any dates rendered an empty badge, and an entry without a
# location rendered a location row containing only the map pin icon.
class EntryRenderingTest < Minitest::Test
  TEMPLATES = %w[experience education].freeze

  def test_missing_end_date_renders_present
    each_template do |name, render|
      expected = name == "experience" ? "01/20 — Present" : "2020 - Present"
      assert_equal [expected], badges(render.call([{ "start_date" => "2020-01-01" }])),
                   "#{name}.liquid should label an open-ended entry as Present"
    end
  end

  def test_blank_end_date_renders_present
    each_template do |name, render|
      expected = name == "experience" ? "01/20 — Present" : "2020 - Present"
      assert_equal [expected], badges(render.call([{ "startDate" => "2020-01-01", "endDate" => "" }])),
                   "#{name}.liquid should label a blank end date as Present"
    end
  end

  def test_closed_entry_renders_both_years
    each_template do |name, render|
      expected = name == "experience" ? "03/15 — 06/18" : "2015 - 2018"
      assert_equal [expected], badges(render.call([{ "start_date" => "2015-03-01", "end_date" => "2018-06-30" }])),
                   "#{name}.liquid should render the start and end years"
    end
  end

  def test_entry_without_dates_renders_no_badge
    each_template do |name, render|
      assert_empty badges(render.call([{ "position" => "Independent Researcher" }])),
                   "#{name}.liquid should not render an empty date badge"
    end
  end

  def test_missing_location_renders_no_location_row
    each_template do |name, render|
      output = render.call([{ "start_date" => "2020-01-01" }])

      refute_includes output, "iconlocation", "#{name}.liquid should not render an empty location row"
      refute_includes output, 'class="location"'
    end
  end

  def test_blank_location_renders_no_location_row
    each_template do |name, render|
      output = render.call([{ "start_date" => "2020-01-01", "location" => "   " }])

      refute_includes output, "iconlocation", "#{name}.liquid should not render a whitespace-only location row"
    end
  end

  def test_present_location_is_rendered
    each_template do |name, render|
      output = render.call([{ "start_date" => "2020-01-01", "location" => "Berlin, Germany" }])

      if name == "experience"
        refute_includes output, "iconlocation"
        assert_includes output, '<span class="location-line location-icon-line" aria-hidden="true">&nbsp;</span>'
        assert_includes output, '<span class="location-line">Berlin</span>'
        assert_includes output, '<span class="location-line">Germany</span>'
      else
        assert_includes output, "iconlocation", "#{name}.liquid should render a location row when a location is set"
        assert_includes output, "Berlin, Germany"
      end
    end
  end

  def test_experience_company_is_italicized
    output = each_template_render("experience", [{ "company" => "Acme Robotics" }])

    assert_match(
      /<h6 class="experience-company">\s*<em class="experience-company-name">\s*Acme Robotics\s*<\/em>\s*<\/h6>/,
      output
    )

    css = ROOT.join("assets/css/al-folio-cv.css").read
    assert_includes css, "em.experience-company-name{font-style:oblique 14deg}"
  end

  private

  def each_template
    TEMPLATES.each do |name|
      template = Liquid::Template.parse(ROOT.join("templates/cv/#{name}.liquid").read)
      yield name, ->(entries) { template.render!("entries" => entries) }
    end
  end

  def each_template_render(name, entries)
    template = Liquid::Template.parse(ROOT.join("templates/cv/#{name}.liquid").read)
    template.render!("entries" => entries)
  end

  def badges(output)
    output.scan(%r{<span class="badge[^>]*>(.*?)</span>}m).map { |match| match[0].strip }
  end
end
