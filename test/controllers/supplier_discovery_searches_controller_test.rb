require "test_helper"

class SupplierDiscoverySearchesControllerTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  setup do
    @password = "Password123!"
    @user = User.create!(
      name: "LeadPulse Test",
      email: "busca@example.com",
      password: @password,
      password_confirmation: @password
    )
  end

  test "redirects guests to sign in" do
    get supplier_discovery_searches_url

    assert_redirected_to new_user_session_path
  end

  test "renders search index for signed users" do
    post user_session_url, params: { user: { email: @user.email, password: @password } }

    get supplier_discovery_searches_url

    assert_response :success
    assert_select "h1", text: /Busca de fornecedores/
    assert_select "button", text: /Nova busca/
    assert_select "#supplier_discovery_search_callback_phone", count: 0
    assert_select "#supplier_discovery_search_callback_contact_name", count: 0
  end

  test "renders supplier locations through the OpenStreetMap controller" do
    @user.supplier_discovery_searches.create!(
      search_id: "search-map-001",
      status: SupplierDiscoverySearch::LOCAL_STATUS_COMPLETED,
      segment_name: "Ferro",
      region: "Campinas",
      response_payload: {
        "suppliers" => [
          {
            "supplier_name" => "Metal Campinas",
            "city" => "Campinas",
            "state" => "SP",
            "latitude" => -22.9056,
            "longitude" => -47.0608,
            "openstreetmap_url" => "https://www.openstreetmap.org/node/123",
            "osm_place_id" => "node:123",
            "location_provider" => "openstreetmap",
            "location_precision" => "openstreetmap_place"
          }
        ]
      }
    )
    post user_session_url, params: { user: { email: @user.email, password: @password } }

    get supplier_discovery_searches_url

    assert_response :success
    assert_select '[data-controller="supplier-map"]', count: 1 do |maps|
      points = JSON.parse(maps.first["data-supplier-map-points-value"])
      assert_equal 1, points.size
      assert_equal "Metal Campinas", points.first["supplier_name"]
      assert_equal "node:123", points.first["osm_place_id"]
      assert_equal "openstreetmap", points.first["location_provider"]
      assert_nil maps.first["data-supplier-map-api-key-value"]
      assert_select '[data-supplier-map-target="canvas"][role="application"]', count: 1
      assert_select '[data-supplier-map-target="placeholder"][hidden]', count: 1
    end
    assert_select "iframe", count: 0
  end

  test "viewer sees saved searches without create or import controls" do
    @user.update!(role: "viewer")
    post user_session_url, params: { user: { email: @user.email, password: @password } }

    get supplier_discovery_searches_url

    assert_response :success
    assert_select "button", text: /Nova busca/, count: 0
    assert_select "#supplier-search-modal", count: 0
  end

  test "queues supplier discovery without waiting for the remote API" do
    @user.update!(validation_api_token: "lp_test_token")
    post user_session_url, params: { user: { email: @user.email, password: @password } }

    assert_enqueued_with(job: SupplierDiscoverySearchJob) do
      post supplier_discovery_searches_url, params: {
        supplier_discovery_search: {
          segment_name: "Adubo",
          region: "Campinas",
          max_suppliers: 5
        }
      }
    end

    assert_redirected_to supplier_discovery_searches_path
    search = @user.supplier_discovery_searches.order(:id).last
    assert_equal SupplierDiscoverySearch::LOCAL_STATUS_PENDING, search.status
    assert_equal "Adubo", search.segment_name
    assert_equal 5, search.request_payload["max_suppliers"]
  end

  test "reports active progress and allows retrying a failed search" do
    search = @user.supplier_discovery_searches.create!(
      search_id: "local-test-retry",
      status: SupplierDiscoverySearch::LOCAL_STATUS_ERROR,
      segment_name: "Ferro",
      error_message: "Falha temporária",
      request_payload: { segment_name: "Ferro", max_suppliers: 3 }
    )
    post user_session_url, params: { user: { email: @user.email, password: @password } }

    assert_enqueued_with(job: SupplierDiscoverySearchJob, args: [ search ]) do
      post retry_search_supplier_discovery_search_url(search)
    end

    assert_redirected_to supplier_discovery_searches_path
    assert_equal SupplierDiscoverySearch::LOCAL_STATUS_PENDING, search.reload.status

    get progress_supplier_discovery_searches_url
    assert_response :success
    payload = JSON.parse(response.body)
    assert payload["active"]
    assert_includes payload["fingerprint"], "#{search.id}:pendente"
  end
end
