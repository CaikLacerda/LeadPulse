require "test_helper"
require "cgi"

class SupplierLocationsHelperTest < ActionView::TestCase
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
            "longitude" => "-47.0608"
          }
        ]
      }
    )

    points = supplier_discovery_map_points([search])

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

    points = supplier_discovery_map_points([search])

    assert_empty points
    assert_equal "Sem coordenadas exatas no mapa", supplier_location_map_meta(points)
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
            "google_maps_url" => "https://www.google.com/maps/place/Rua+Um,+122"
          }
        ]
      }
    )

    point = supplier_discovery_map_points([search]).first
    decoded_url = CGI.unescape(point[:google_maps_url])

    assert_includes decoded_url, "Aserferro Distribuidora de Ferro e Aço Ltda"
    assert_includes decoded_url, "Monte Mor"
    refute_includes decoded_url, "/place/Rua"
  end
end
