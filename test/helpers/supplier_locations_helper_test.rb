require "test_helper"
require "cgi"

class SupplierLocationsHelperTest < ActionView::TestCase
  test "builds an OpenStreetMap point without a Google place id" do
    search = SupplierDiscoverySearch.create!(
      user: users(:one),
      search_id: "search-with-openstreetmap-location",
      status: SupplierDiscoverySearch::LOCAL_STATUS_COMPLETED,
      segment_name: "Ferro",
      region: "Campinas",
      response_payload: {
        "suppliers" => [
          {
            "supplier_name" => "JOBAMA Ferro & Aço",
            "latitude" => "-22.9561",
            "longitude" => "-47.0112",
            "openstreetmap_url" => "https://www.openstreetmap.org/node/123",
            "osm_place_id" => "node:123",
            "location_provider" => "openstreetmap",
            "location_precision" => "openstreetmap_place"
          }
        ]
      }
    )

    point = supplier_discovery_map_points([ search ]).first

    assert_equal "JOBAMA Ferro & Aço", point[:supplier_name]
    assert_equal "node:123", point[:osm_place_id]
    assert_equal "https://www.openstreetmap.org/node/123", point[:openstreetmap_url]
    assert_equal "openstreetmap", point[:location_provider]
    assert_match %r{\Ahttps://www\.google\.com/maps/search/\?api=1&query=}, point[:google_maps_url]
  end

  test "builds clickable Google Maps points from supplier coordinates" do
    search = SupplierDiscoverySearch.create!(
      user: users(:one),
      search_id: "search-with-location",
      status: SupplierDiscoverySearch::LOCAL_STATUS_COMPLETED,
      segment_name: "Adubo",
      region: "Campinas",
      response_payload: {
        "suppliers" => [
          {
            "supplier_name" => "Agro Campinas",
            "phone" => "19999999999",
            "city" => "Campinas",
            "state" => "SP",
            "latitude" => "-22.9056",
            "longitude" => "-47.0608",
            "google_place_id" => "ChIJagroCampinas"
          }
        ]
      }
    )

    points = supplier_discovery_map_points([ search ])

    assert_equal 1, points.size
    assert_equal "Agro Campinas", points.first[:supplier_name]
    assert_equal false, points.first[:approximate]
    assert_match %r{\Ahttps://www\.google\.com/maps/search/\?api=1&query=}, points.first[:google_maps_url]
  end

  test "does not plot city or state fallback when exact coordinates are absent" do
    search = SupplierDiscoverySearch.create!(
      user: users(:one),
      search_id: "search-with-state",
      status: SupplierDiscoverySearch::LOCAL_STATUS_COMPLETED,
      segment_name: "Embalagem",
      region: "São Paulo",
      response_payload: {
        "suppliers" => [
          {
            "supplier_name" => "Embalagens Paulista",
            "phone" => "11999999999",
            "state" => "SP"
          }
        ]
      }
    )

    points = supplier_discovery_map_points([ search ])

    assert_empty points
    assert_equal "Sem coordenadas localizadas no mapa", supplier_location_map_meta(points)
  end

  test "does not present approximate coordinates as an exact supplier point" do
    search = SupplierDiscoverySearch.create!(
      user: users(:one),
      search_id: "search-with-approximate-location",
      status: SupplierDiscoverySearch::LOCAL_STATUS_COMPLETED,
      segment_name: "Ferro",
      region: "Campinas",
      response_payload: {
        "suppliers" => [
          {
            "supplier_name" => "Fornecedor sem local confirmado",
            "latitude" => "-22.9056",
            "longitude" => "-47.0608",
            "location_precision" => "approximate"
          }
        ]
      }
    )

    assert_empty supplier_discovery_map_points([ search ])
  end

  test "plots an OpenStreetMap road fallback as approximate" do
    search = SupplierDiscoverySearch.create!(
      user: users(:one),
      search_id: "search-with-road-fallback",
      status: SupplierDiscoverySearch::LOCAL_STATUS_COMPLETED,
      segment_name: "Ferro",
      region: "Campinas",
      response_payload: {
        "suppliers" => [
          {
            "supplier_name" => "Fornecedor na via",
            "latitude" => "-22.9138",
            "longitude" => "-47.0600",
            "location_precision" => "openstreetmap_road",
            "openstreetmap_url" => "https://www.openstreetmap.org/way/359848114"
          }
        ]
      }
    )

    point = supplier_discovery_map_points([ search ]).first

    assert point[:approximate]
    assert_equal "openstreetmap_road", point[:location_precision]
  end

  test "opens Maps by supplier name instead of explicit street url" do
    search = SupplierDiscoverySearch.create!(
      user: users(:one),
      search_id: "search-with-street-maps-url",
      status: SupplierDiscoverySearch::LOCAL_STATUS_COMPLETED,
      segment_name: "Ferro",
      region: "Campinas",
      response_payload: {
        "suppliers" => [
          {
            "supplier_name" => "Aserferro Distribuidora de Ferro e Aço Ltda",
            "address" => "Rua Um, 122, Anexo, Monte Mor - SP",
            "city" => "Monte Mor",
            "state" => "SP",
            "latitude" => "-22.946",
            "longitude" => "-47.312",
            "google_maps_url" => "https://www.google.com/maps/place/Rua+Um,+122",
            "google_place_id" => "ChIJaserferroExact"
          }
        ]
      }
    )

    point = supplier_discovery_map_points([ search ]).first
    decoded_url = CGI.unescape(point[:google_maps_url])

    assert_includes decoded_url, "Aserferro Distribuidora de Ferro e Aço Ltda"
    assert_includes decoded_url, "Monte Mor"
    refute_includes decoded_url, "/place/Rua"
  end

  test "opens the exact Google place when the API returns a place id" do
    search = SupplierDiscoverySearch.create!(
      user: users(:one),
      search_id: "search-with-place-id",
      status: SupplierDiscoverySearch::LOCAL_STATUS_COMPLETED,
      segment_name: "Ferro",
      region: "Campinas",
      response_payload: {
        "suppliers" => [
          {
            "supplier_name" => "Metal Campinas",
            "city" => "Campinas",
            "state" => "SP",
            "latitude" => "-22.9056",
            "longitude" => "-47.0608",
            "google_place_id" => "ChIJexactSupplier123"
          }
        ]
      }
    )

    point = supplier_discovery_map_points([ search ]).first
    decoded_url = CGI.unescape(point[:google_maps_url])

    assert_includes decoded_url, "query=Metal Campinas, Campinas, SP, Brasil"
    assert_includes decoded_url, "query_place_id=ChIJexactSupplier123"
  end

  test "uses the exact address in the Maps query when city fields are absent" do
    search = SupplierDiscoverySearch.create!(
      user: users(:one),
      search_id: "search-with-address-only",
      status: SupplierDiscoverySearch::LOCAL_STATUS_COMPLETED,
      segment_name: "Ferro",
      region: "Campinas",
      response_payload: {
        "suppliers" => [
          {
            "supplier_name" => "Ferro São Paulo",
            "formatted_address" => "Praça da Sé, São Paulo - SP",
            "latitude" => "-23.5505",
            "longitude" => "-46.6333",
            "google_place_id" => "ChIJexactAddress123"
          }
        ]
      }
    )

    point = supplier_discovery_map_points([ search ]).first
    decoded_url = CGI.unescape(point[:google_maps_url])

    assert_includes decoded_url, "Praça da Sé, São Paulo - SP"
    refute_includes decoded_url, "Campinas"
  end
end
