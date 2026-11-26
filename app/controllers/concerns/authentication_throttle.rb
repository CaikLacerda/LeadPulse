module AuthenticationThrottle
  extend ActiveSupport::Concern

  included do
    before_action :throttle_authentication, only: :create
  end

  private

  def throttle_authentication
    identity = params.dig(:user, :email).to_s.strip.downcase
    ip = request.remote_ip.to_s
    scope = controller_name
    # Another IP cannot lock out a victim by guessing their identity. The IP
    # budget also bounds rotating usernames from a single source.
    budgets = [ [ "ip", ip, 20, 5.minutes ], [ "identity_ip", "#{identity}:#{ip}", 5, 1.minute ] ]
    budgets.each do |name, value, limit, window|
      key = "authentication:#{scope}:#{name}:#{Digest::SHA256.hexdigest(value)}"
      count = Rails.cache.increment(key, 1, expires_in: window)
      raise "Authentication counter unavailable" if count.nil?
      next if count <= limit

      Rails.logger.warn("security_event=authentication_throttled scope=#{scope} budget=#{name} request_id=#{request.request_id}")
      response.set_header("Retry-After", window.to_i.to_s)
      render plain: "Muitas tentativas. Aguarde e tente novamente.", status: :too_many_requests
      return
    end
  rescue StandardError => error
    Rails.logger.error("security_event=authentication_throttle_unavailable error_class=#{error.class.name}")
    head :service_unavailable
  end
end
