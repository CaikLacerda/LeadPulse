module DisplayCodeSearchable
  extend ActiveSupport::Concern

  private

  def extract_display_number(value, prefix:)
    value.to_s.strip.match(/\A(?:#{Regexp.escape(prefix)}-?)?0*(\d+)\z/i)&.captures&.first&.to_i
  end
end
