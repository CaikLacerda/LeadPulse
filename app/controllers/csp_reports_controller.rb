class CspReportsController < ActionController::Base
  skip_forgery_protection

  def create
    return head :content_too_large if request.content_length.to_i > 16_384

    payload = JSON.parse(request.body.read(16_385))
    directive = payload.dig("csp-report", "effective-directive").to_s
    # Never log URLs (query strings may carry tokens), scripts, or arbitrary text.
    if directive.match?(/\A[a-z-]{1,40}\z/)
      count = Rails.cache.increment("csp-reports:#{request.remote_ip}", 1, expires_in: 1.minute)
      Rails.logger.info("security_event=csp_violation directive=#{directive}") if count && count <= 20
    end
    head :no_content
  rescue JSON::ParserError, TypeError, NoMethodError
    head :bad_request
  end
end
