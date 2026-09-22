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
        assert_includes output, '<div class="description-border experience-location-border">'
        assert_match(/<span class="location-line(?: experience-location-text)?">\s*Berlin, Germany\s*<\/span>/, output)
      else
        assert_includes output, "iconlocation", "#{name}.liquid should render a location row when a location is set"
        assert_includes output, "Berlin, Germany"
      end
    end
  end

  def test_city_only_experience_location_has_no_state_border
    output = each_template_render("experience", [{ "start_date" => "2020-01-01", "location" => "San Jose" }])

    assert_match(/<span class="location-line(?: experience-location-text)?">\s*San Jose\s*<\/span>/, output)
    refute_includes output, "location-state-border"
  end

  def test_experience_company_is_italicized
    output = each_template_render("experience", [{ "company" => "Acme Robotics" }])

    assert_match(
      /<h6 class="experience-company description-title">\s*<em class="experience-company-name">\s*Acme Robotics\s*<\/em>\s*<\/h6>/,
      output
    )

    css = ROOT.join("assets/css/al-folio-cv.css").read
    assert_includes css, "em.experience-company-name{font-style:oblique 14deg}"
    assert_includes css, "em.experience-company-name{opacity:1}"
    assert_includes css, "div.experience-details .experience-company.description-title{font-weight:400!important}"
  end

  def test_experience_location_box_uses_the_shared_border
    template = ROOT.join("templates/cv/experience.liquid").read
    css = ROOT.join("assets/css/al-folio-cv.css").read

    assert_includes template, '<div class="description-border experience-location-border">'
    assert_includes template, 'experience-date experience-location-text'
    assert_includes template, 'location-line experience-location-text'
    assert_includes template, 'description-title'
    assert_includes css, 'div.experience-location-border .experience-location-text{transition:color .2s ease}'
    assert_includes css, 'div.experience-location-border:hover .experience-location-text'
    assert_includes css, '@media (prefers-reduced-motion:reduce){div.experience-location-border .experience-location-text{transition:none}html.transition div.experience-location-border .experience-location-text{transition:none!important}}'
    refute_includes css, "table.experience-location-table tr:first-child td{border-top:"
    refute_includes css, "table.experience-location-table tr:nth-child(2) td{border-top:"
    refute_includes css, "location-state-border"
    assert_includes css, "div.experience-location-border{width:100%;max-width:100%;padding-left:0;padding-right:0}"
    assert_includes css, "div.experience-location-border{padding-top:.25rem;padding-bottom:.375rem}"
    assert_includes css, "table.experience-location-table td{padding-left:0;padding-right:0;border:0}"
    assert_includes css, "table-layout:fixed"
    assert_includes css, "p.experience-location{top:0;margin:0;white-space:normal;overflow-wrap:anywhere}"
    assert_includes css, "div.experience-location-border .experience-date,div.experience-location-border p.experience-location{line-height:1}"
    assert_includes css, "div.cv ul.experience-list>li.list-group-item+li.list-group-item{margin-top:22.5px}"
    assert_includes css, "@media (min-width:576px){div.cv ul.experience-list>li.list-group-item+li.list-group-item{margin-top:26.5px}}"
    assert_includes css, "h6.experience-role,h6.experience-company{font-size:1.0555556rem}"
    assert_includes css, "h6.experience-role{margin-bottom:0}"
    assert_includes css, "h2.previous-role-heading{margin-bottom:22.5px}"
  end

  def test_experience_details_use_the_shared_description_width
    template = ROOT.join("templates/cv/experience.liquid").read
    css = ROOT.join("assets/css/al-folio-cv.css").read

    assert_includes template, '<div class="col-sm-8 experience-details">'
    assert_includes css, "div.experience-details{flex:0 0 66.6667%;max-width:66.6667%}"
    assert_includes css, "div.experience-details>.description-border{width:100%;max-width:100%}"
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
