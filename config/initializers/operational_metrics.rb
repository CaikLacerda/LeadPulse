# A dedicated JSON stream preserves EMF syntax; normal logs retain request_id tags.
if Rails.env.production? && ENV["OPERATIONAL_METRICS_ENABLED"] != "false"
  metric_logger = Logger.new(ENV.fetch("METRICS_LOG_PATH", $stdout))
  metric_logger.formatter = ->(_severity, _time, _progname, message) { "#{message}\n" }
  ActiveSupport::Notifications.monotonic_subscribe("process_action.action_controller") do |_name, started, finished, _id, payload|
    status = payload[:status] || (payload[:exception] ? 500 : 200)
    values = { Requests: 1, LatencyMs: (finished - started) * 1000,
               ClientErrors: (400...500).cover?(status) ? 1 : 0, ServerErrors: status >= 500 ? 1 : 0 }
    metrics = values.keys.map { |name| { Name: name, Unit: name == :LatencyMs ? "Milliseconds" : "Count" } }
    metric_logger.info({
      _aws: { Timestamp: (Time.now.to_f * 1000).to_i, CloudWatchMetrics: [
        { Namespace: "LeadPulse", Dimensions: [ [ "Service" ] ], Metrics: metrics }
      ] }, Service: "rails", **values
    }.to_json)
  end
end
