require "test_helper"

class ProviderNetworkGuardTest < ActiveSupport::TestCase
  test "provider HTTP and sockets fail without making a connection" do
    assert_raises(Typhoeus::Errors::NoStub) { Typhoeus.get("https://api.twilio.com/") }
    assert_raises(Testing::NetworkGuard::ExternalNetworkBlocked) { TCPSocket.new("api.openai.com", 443) }
  end
end
