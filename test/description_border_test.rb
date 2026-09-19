# frozen_string_literal: true

require_relative "test_helper"

class DescriptionBorderTest < Minitest::Test
  TEMPLATES = %w[experience education projects publications awards references].freeze

  def test_each_detailed_entry_renderer_wraps_its_text_body
    TEMPLATES.each do |name|
      template = ROOT.join("templates/cv/#{name}.liquid").read

      assert_includes template, 'class="description-border"', "#{name}.liquid should use the shared wrapper"
    end
  end

  def test_date_columns_and_locations_remain_outside_the_wrappers
    %w[experience education projects publications awards].each do |name|
      template = ROOT.join("templates/cv/#{name}.liquid").read
      wrapper_start = template.index('<div class="description-border">')

      assert_operator template.index("date", 0), :<, wrapper_start, "#{name}.liquid should keep date markup outside"
    end

    experience = ROOT.join("templates/cv/experience.liquid").read
    assert_operator experience.index("experience-location-column"), :<, experience.index('<div class="description-border">')
  end

  def test_title_columns_do_not_keep_the_old_left_margin_offsets
    %w[education publications awards].each do |name|
      template = ROOT.join("templates/cv/#{name}.liquid").read

      refute_includes template, "ml-1 ml-md-4", "#{name}.liquid should align its title with the border"
    end
  end
end
