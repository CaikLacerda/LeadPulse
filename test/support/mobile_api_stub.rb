module MobileApiStub
  def stub_mobile_api(dashboard: nil, calls: nil)
    originals = {}
    { DashboardService: dashboard, CallsService: calls }.each do |name, value|
      klass = "ValidationApi::Mobile::#{name}".constantize
      originals[klass] = klass.instance_method(:call)
      klass.define_method(:call) do |**args|
        raise value if value.is_a?(Exception)
        value.is_a?(Proc) ? value.call(**args) : value
      end
    end
    yield
  ensure
    originals.each { |klass, method| klass.define_method(:call, method) }
  end
end
