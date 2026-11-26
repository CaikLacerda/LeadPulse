module SupplierLocationsHelper
  BRAZIL_MAP_BOUNDS = {
    min_lat: -35.0,
    max_lat: 6.0,
    min_lng: -75.0,
    max_lng: -24.0
  }.freeze

  LOCATION_ADDRESS_KEYS = %w[
    formatted_address
    full_address
    address
    street_address
    location_address
    google_address
  ].freeze

  SUPPLIER_NAME_KEYS = %w[
    supplier_name
    name
    company_name
    companyName
    empresa
    razao_social
    corporate_name
    business_name
    title
  ].freeze

  LOCATION_URL_KEYS = %w[
    google_maps_url
    google_maps_uri
    googleMapsUri
    maps_url
    place_url
  ].freeze

  PLACE_ID_KEYS = %w[
    google_place_id
    googlePlaceId
    place_id
  ].freeze

  EXACT_LOCATION_PRECISIONS = %w[
    google_place
    openstreetmap_place
    openstreetmap_address
    openstreetmap_road
  ].freeze

  def supplier_discovery_map_points(searches, limit: 70)
    points = Array(searches).flat_map do |search|
      Array(search.suppliers).filter_map do |supplier|
        supplier_location_point(search, supplier)
      end
    end.uniq { |point| point[:dedupe_key] }.first(limit)

    points
  end

  def supplier_location_map_meta(points)
    count = Array(points).size
    return "Sem coordenadas localizadas no mapa" if count.zero?

    "#{count} ponto#{'s' unless count == 1} localizado#{'s' unless count == 1} no Brasil"
  end

  private

  def supplier_location_point(search, raw_supplier)
    supplier = stringify_supplier(raw_supplier)
    place_id = first_present_value(supplier, PLACE_ID_KEYS) || first_present_value(nested_location_hash(supplier), PLACE_ID_KEYS)
    location_precision = supplier["location_precision"].presence || nested_location_hash(supplier)["location_precision"].presence
    return unless place_id.present? || EXACT_LOCATION_PRECISIONS.include?(location_precision)

    coordinates = supplier_location_coordinates(supplier)
    return if coordinates.blank?

    supplier_name = supplier_name_from(supplier) || "Fornecedor"
    location_text = supplier_location_text(supplier, search.region)
    maps_query = supplier_maps_query(supplier, search.region, coordinates)

    {
      supplier_name: supplier_name,
      location_label: location_text.presence || coordinates[:source],
      segment_name: search.segment_name,
      search_display_code: search.display_code,
      lat: coordinates[:lat],
      lng: coordinates[:lng],
      approximate: location_precision == "openstreetmap_road",
      google_place_id: place_id,
      osm_place_id: supplier["osm_place_id"],
      openstreetmap_url: supplier["openstreetmap_url"],
      location_provider: supplier["location_provider"],
      location_precision: location_precision,
      google_maps_url: supplier_google_maps_url(supplier, maps_query, coordinates),
      maps_query: maps_query,
      dedupe_key: [ supplier_name, location_text, coordinates[:lat], coordinates[:lng] ].join("|").downcase
    }
  end

  def stringify_supplier(raw_supplier)
    return raw_supplier.deep_stringify_keys if raw_supplier.respond_to?(:deep_stringify_keys)

    {}
  end

  def supplier_location_coordinates(supplier)
    location = nested_location_hash(supplier)
    lat = decimal_from_keys(supplier, %w[latitude lat]) || decimal_from_keys(location, %w[latitude lat])
    lng = decimal_from_keys(supplier, %w[longitude lng lon long]) || decimal_from_keys(location, %w[longitude lng lon long])

    if brazil_coordinate?(lat, lng)
      { lat: lat, lng: lng, source: "Coordenada do fornecedor", approximate: false }
    end
  end

  def nested_location_hash(supplier)
    location = supplier["location"]
    return location.deep_stringify_keys if location.respond_to?(:deep_stringify_keys)

    {}
  end

  def decimal_from_keys(hash, keys)
    keys.filter_map { |key| decimal_coordinate(hash[key]) }.first
  end

  def decimal_coordinate(value)
    return if value.blank?

    Float(value.to_s.tr(",", "."))
  rescue ArgumentError, TypeError
    nil
  end

  def brazil_coordinate?(lat, lng)
    return false if lat.blank? || lng.blank?

    lat.between?(BRAZIL_MAP_BOUNDS[:min_lat], BRAZIL_MAP_BOUNDS[:max_lat]) &&
      lng.between?(BRAZIL_MAP_BOUNDS[:min_lng], BRAZIL_MAP_BOUNDS[:max_lng])
  end

  def supplier_location_text(supplier, fallback_region = nil)
    location = nested_location_hash(supplier)
    address = first_present_value(supplier, LOCATION_ADDRESS_KEYS) || first_present_value(location, LOCATION_ADDRESS_KEYS)
    city = supplier["city"].presence || location["city"].presence
    state = supplier["state"].presence || supplier["uf"].presence || location["state"].presence || location["uf"].presence
    city_state = [ city, state ].compact_blank.join(" - ").presence
    city_state = fallback_region if city.blank? && state.present? && fallback_region.present?

    [ address, city_state, fallback_region ].compact_blank.first
  end

  def supplier_maps_query(supplier, fallback_region, coordinates)
    supplier_name = supplier_name_from(supplier)
    return "#{coordinates[:lat]},#{coordinates[:lng]}" if supplier_name.blank?

    location = nested_location_hash(supplier)
    city = supplier["city"].presence || location["city"].presence
    state = supplier["state"].presence || supplier["uf"].presence || location["state"].presence || location["uf"].presence
    address = first_present_value(supplier, LOCATION_ADDRESS_KEYS) || first_present_value(location, LOCATION_ADDRESS_KEYS)
    location_hint = [ city, state ].compact_blank.join(", ").presence || address || fallback_region

    [ supplier_name, location_hint, "Brasil" ].compact_blank.uniq.join(", ").truncate(180, omission: "")
  end

  def supplier_google_maps_url(supplier, query, coordinates)
    location = nested_location_hash(supplier)
    supplier_name = supplier_name_from(supplier)

    place_id = first_present_value(supplier, PLACE_ID_KEYS) || first_present_value(location, PLACE_ID_KEYS)
    query_value = query.presence || "#{coordinates[:lat]},#{coordinates[:lng]}"
    url = "https://www.google.com/maps/search/?api=1&query=#{ERB::Util.url_encode(query_value)}"
    url += "&query_place_id=#{ERB::Util.url_encode(place_id)}" if place_id.present?
    return "#{url}&utm_source=LeadPulse&utm_campaign=supplier_location_search" if supplier_name.present?

    explicit_url = first_present_value(supplier, LOCATION_URL_KEYS) || first_present_value(location, LOCATION_URL_KEYS)
    explicit_url.to_s.start_with?("http://", "https://") ? explicit_url : "#{url}&utm_source=LeadPulse&utm_campaign=supplier_location_search"
  end

  def first_present_value(hash, keys)
    keys.filter_map { |key| hash[key].presence }.first
  end

  def supplier_name_from(supplier)
    first_present_value(supplier, SUPPLIER_NAME_KEYS)
  end
end
