require "test_helper"

class SupplierDiscoverySearchJobTest < ActiveJob::TestCase
  setup do
    @user = users(:one)
    @user.update!(validation_api_token: "lp_test_token")
    @search = @user.supplier_discovery_searches.create!(
      search_id: "local-job-test",
      status: SupplierDiscoverySearch::LOCAL_STATUS_PENDING,
      segment_name: "Adubo",
      region: "Campinas",
      request_payload: {
        segment_name: "Adubo",
        region: "Campinas",
        max_suppliers: 2,
        include_locations: true
      }
    )
  end

  test "completes a queued search and stores its downloadable result" do
    remote_service = Object.new
    remote_service.define_singleton_method(:call) do |api_token:, payload:|
      raise "token ausente" if api_token.blank?
      raise "payload incorreto" unless payload[:segment_name] == "Adubo"

      {
        "search_id" => "supplier-search-remote-001",
        "mode" => "openai_web_search",
        "segment_name" => "Adubo",
        "region" => "Campinas",
        "generated_at" => Time.current.iso8601,
        "total_suppliers" => 2,
        "suppliers" => [
          {
            "supplier_name" => "Fornecedor localizado",
            "phone" => "+5519999999999",
            "latitude" => -22.9,
            "longitude" => -47.06
          },
          {
            "supplier_name" => "Fornecedor sem telefone",
            "phone" => nil
          }
        ],
        "downloadable_file_url" => "/supplier-discovery/remote/results.xlsx"
      }
    end

    job = SupplierDiscoverySearchJob.new
    job.define_singleton_method(:remote_search_service) do |search|
      SupplierDiscoverySearches::CreateRemoteSearchService.new(search:, remote_service:)
    end
    job.perform(@search)

    @search.reload
    assert @search.completed?
    assert_equal "supplier-search-remote-001", @search.search_id
    assert_equal 1, @search.total_suppliers
    assert_equal 1, @search.suppliers.size
    assert @search.download_ready?
    assert_nil @search.error_message
  end

  test "marks the search as failed when the remote API rejects it" do
    remote_service = Object.new
    remote_service.define_singleton_method(:call) do |**|
      raise ValidationApi::Error, "Provedor indisponível"
    end

    job = SupplierDiscoverySearchJob.new
    job.define_singleton_method(:remote_search_service) do |search|
      SupplierDiscoverySearches::CreateRemoteSearchService.new(search:, remote_service:)
    end
    job.perform(@search)

    @search.reload
    assert @search.errored?
    assert_equal "Provedor indisponível", @search.error_message
  end
end
