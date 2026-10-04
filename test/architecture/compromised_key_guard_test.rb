require "test_helper"
require "open3"
require_relative "../../lib/security/compromised_key_guard"

class CompromisedKeyGuardTest < ActiveSupport::TestCase
  test "compromised fingerprints are rejected without disclosing the material" do
    key, status = Open3.capture2("git", "show", "68f23d7:config/master.key")
    skip "Historical object unavailable in shallow checkout" unless status.success?
    error = assert_raises(RuntimeError) { Security::CompromisedKeyGuard.check!(key) }
    refute error.message.include?(key.strip)
    assert_nil Security::CompromisedKeyGuard.check!(SecureRandom.hex(16))
  end

  test "secret key files are absent from the Git index" do
    assert system(Rails.root.join("bin/security_check").to_s)
  end
end
