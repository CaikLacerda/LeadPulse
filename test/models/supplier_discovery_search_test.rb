require "test_helper"

class SupplierDiscoverySearchTest < ActiveSupport::TestCase
  test "recognizes queued and processing searches as active" do
    search = SupplierDiscoverySearch.new(status: SupplierDiscoverySearch::LOCAL_STATUS_PENDING)

    assert search.pending?
    assert search.active?

    search.status = SupplierDiscoverySearch::LOCAL_STATUS_PROCESSING
    assert search.processing?
    assert search.active?

    search.status = SupplierDiscoverySearch::LOCAL_STATUS_COMPLETED
    assert search.completed?
    assert_not search.active?
  end

  test "keeps OpenStreetMap metadata when a search becomes a validation candidate" do
    search = SupplierDiscoverySearch.create!(
      user: users(:one),
      search_id: "search-osm-custom-fields",
      status: SupplierDiscoverySearch::LOCAL_STATUS_COMPLETED,
      segment_name: "Ferro",
      region: "Campinas",
      response_payload: {
        "suppliers" => [
          {
            "supplier_name" => "Fornecedor OSM",
            "phone" => "+5519999999999",
            "latitude" => -22.9138,
            "longitude" => -47.0600,
            "openstreetmap_url" => "https://www.openstreetmap.org/way/359848114",
            "osm_place_id" => "way:359848114",
            "location_provider" => "openstreetmap",
            "location_precision" => "openstreetmap_road"
          }
        ]
      }
    )

    custom_fields = search.valid_supplier_candidates.first.fetch(:custom_fields)

    assert_equal "https://www.openstreetmap.org/way/359848114", custom_fields["openstreetmap_url"]
    assert_equal "way:359848114", custom_fields["osm_place_id"]
    assert_equal "openstreetmap", custom_fields["location_provider"]
    assert_equal "openstreetmap_road", custom_fields["location_precision"]
  end
end
