module SupplierLocationsHelper
  BRAZIL_MAP_BOUNDS = {
    min_lat: -35.0,
    max_lat: 6.0,
    min_lng: -75.0,
    max_lng: -24.0
  }.freeze

  BRAZIL_STATE_COORDINATES = {
    'AC' => [-8.77, -70.55],
    'AL' => [-9.57, -36.78],
    'AP' => [1.41, -51.77],
    'AM' => [-3.47, -65.1],
    'BA' => [-12.96, -38.51],
    'CE' => [-5.2, -39.53],
    'DF' => [-15.78, -47.93],
    'ES' => [-19.19, -40.34],
    'GO' => [-16.64, -49.31],
    'MA' => [-5.42, -45.44],
    'MT' => [-12.64, -55.42],
    'MS' => [-20.51, -54.54],
    'MG' => [-18.1, -44.38],
    'PA' => [-3.79, -52.48],
    'PB' => [-7.24, -36.78],
    'PR' => [-24.89, -51.55],
    'PE' => [-8.28, -35.07],
    'PI' => [-6.6, -42.28],
    'RJ' => [-22.84, -43.15],
    'RN' => [-5.81, -36.59],
    'RS' => [-30.01, -51.22],
    'RO' => [-10.83, -63.34],
    'RR' => [2.05, -61.4],
    'SC' => [-27.33, -49.44],
    'SP' => [-22.19, -48.79],
    'SE' => [-10.57, -37.45],
    'TO' => [-10.25, -48.25]
  }.freeze

  BRAZIL_STATE_ALIASES = {
    'acre' => 'AC',
    'alagoas' => 'AL',
    'amapa' => 'AP',
    'amazonas' => 'AM',
    'bahia' => 'BA',
    'ceara' => 'CE',
    'distrito federal' => 'DF',
    'espirito santo' => 'ES',
    'goias' => 'GO',
    'maranhao' => 'MA',
    'mato grosso' => 'MT',
    'mato grosso do sul' => 'MS',
    'minas gerais' => 'MG',
    'para' => 'PA',
    'paraiba' => 'PB',
    'parana' => 'PR',
    'pernambuco' => 'PE',
    'piaui' => 'PI',
    'rio de janeiro' => 'RJ',
    'rio grande do norte' => 'RN',
    'rio grande do sul' => 'RS',
    'rondonia' => 'RO',
    'roraima' => 'RR',
    'santa catarina' => 'SC',
    'sao paulo' => 'SP',
    'sergipe' => 'SE',
    'tocantins' => 'TO'
  }.freeze

  BRAZIL_CITY_COORDINATES = {
    'belem' => [-1.4558, -48.5039],
    'belo horizonte' => [-19.9167, -43.9345],
    'brasilia' => [-15.7939, -47.8828],
    'campinas' => [-22.9056, -47.0608],
    'campo grande' => [-20.4697, -54.6201],
    'cuiaba' => [-15.6014, -56.0979],
    'curitiba' => [-25.4284, -49.2733],
    'florianopolis' => [-27.5949, -48.5482],
    'fortaleza' => [-3.7319, -38.5267],
    'goiania' => [-16.6869, -49.2648],
    'manaus' => [-3.119, -60.0217],
    'porto alegre' => [-30.0346, -51.2177],
    'recife' => [-8.0476, -34.877],
    'ribeirao preto' => [-21.1775, -47.8103],
    'rio de janeiro' => [-22.9068, -43.1729],
    'salvador' => [-12.9777, -38.5016],
    'sao paulo' => [-23.5505, -46.6333],
    'vitoria' => [-20.3155, -40.3128]
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
  ].freeze

  def supplier_discovery_map_points(searches, limit: 70)
    points = Array(searches).flat_map do |search|
      Array(search.suppliers).filter_map do |supplier|
        supplier_location_point(search, supplier)
      end
    end.uniq { |point| point[:dedupe_key] }.first(limit)

    spread_clustered_map_points(points)
  end

  def supplier_location_map_meta(points)
    count = Array(points).size
    return 'Sem coordenadas exatas no mapa' if count.zero?

    "#{count} ponto#{'s' unless count == 1} exato#{'s' unless count == 1} no Brasil"
  end

  def google_maps_brazil_embed_url
    'https://www.google.com/maps?ll=-14.235004,-51.92528&z=4&hl=pt-BR&output=embed'
  end

  def google_maps_browser_api_key
    ENV['GOOGLE_MAPS_BROWSER_API_KEY'].presence || ENV['GOOGLE_MAPS_API_KEY'].presence
  end

  private

  def supplier_location_point(search, raw_supplier)
    supplier = stringify_supplier(raw_supplier)
    coordinates = supplier_location_coordinates(supplier)
    return if coordinates.blank?

    projection = supplier_map_projection(coordinates[:lat], coordinates[:lng])
    supplier_name = supplier_name_from(supplier) || 'Fornecedor'
    location_text = supplier_location_text(supplier, search.region)
    maps_query = supplier_maps_query(supplier, search.region, coordinates)

    {
      supplier_name: supplier_name,
      location_label: location_text.presence || coordinates[:source],
      segment_name: search.segment_name,
      search_display_code: search.display_code,
      lat: coordinates[:lat],
      lng: coordinates[:lng],
      x: projection[:x],
      y: projection[:y],
      approximate: coordinates[:approximate],
      google_maps_url: supplier_google_maps_url(supplier, maps_query, coordinates),
      maps_query: maps_query,
      dedupe_key: [supplier_name, location_text, coordinates[:lat], coordinates[:lng]].join('|').downcase
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
      return { lat: lat, lng: lng, source: 'Coordenada do fornecedor', approximate: false }
    end
  end

  def nested_location_hash(supplier)
    location = supplier['location']
    return location.deep_stringify_keys if location.respond_to?(:deep_stringify_keys)

    {}
  end

  def decimal_from_keys(hash, keys)
    keys.filter_map { |key| decimal_coordinate(hash[key]) }.first
  end

  def decimal_coordinate(value)
    return if value.blank?

    Float(value.to_s.tr(',', '.'))
  rescue ArgumentError, TypeError
    nil
  end

  def brazil_coordinate?(lat, lng)
    return false if lat.blank? || lng.blank?

    lat.between?(BRAZIL_MAP_BOUNDS[:min_lat], BRAZIL_MAP_BOUNDS[:max_lat]) &&
      lng.between?(BRAZIL_MAP_BOUNDS[:min_lng], BRAZIL_MAP_BOUNDS[:max_lng])
  end

  def supplier_state_code(value)
    normalized = normalized_location_key(value)
    return normalized.upcase if normalized.match?(/\A[a-z]{2}\z/) && BRAZIL_STATE_COORDINATES.key?(normalized.upcase)

    BRAZIL_STATE_ALIASES[normalized]
  end

  def normalized_location_key(value)
    ActiveSupport::Inflector.transliterate(value.to_s).downcase.gsub(/[^a-z0-9]+/, ' ').squish
  end

  def supplier_location_text(supplier, fallback_region = nil)
    location = nested_location_hash(supplier)
    address = first_present_value(supplier, LOCATION_ADDRESS_KEYS) || first_present_value(location, LOCATION_ADDRESS_KEYS)
    city = supplier['city'].presence || location['city'].presence
    state = supplier['state'].presence || supplier['uf'].presence || location['state'].presence || location['uf'].presence
    city_state = [city, state].compact_blank.join(' - ').presence
    city_state = fallback_region if city.blank? && state.present? && fallback_region.present?

    [address, city_state, fallback_region].compact_blank.first
  end

  def supplier_maps_query(supplier, fallback_region, coordinates)
    supplier_name = supplier_name_from(supplier)
    return "#{coordinates[:lat]},#{coordinates[:lng]}" if supplier_name.blank?

    location = nested_location_hash(supplier)
    city = supplier['city'].presence || location['city'].presence
    state = supplier['state'].presence || supplier['uf'].presence || location['state'].presence || location['uf'].presence
    location_hint = [city, state].compact_blank.join(', ').presence || fallback_region

    [supplier_name, location_hint, 'Brasil'].compact_blank.uniq.join(', ').truncate(180, omission: '')
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
    explicit_url.to_s.start_with?('http://', 'https://') ? explicit_url : "#{url}&utm_source=LeadPulse&utm_campaign=supplier_location_search"
  end

  def first_present_value(hash, keys)
    keys.filter_map { |key| hash[key].presence }.first
  end

  def supplier_name_from(supplier)
    first_present_value(supplier, SUPPLIER_NAME_KEYS)
  end

  def supplier_map_projection(lat, lng)
    x = ((lng - BRAZIL_MAP_BOUNDS[:min_lng]) / (BRAZIL_MAP_BOUNDS[:max_lng] - BRAZIL_MAP_BOUNDS[:min_lng])) * 100
    top = mercator_y(BRAZIL_MAP_BOUNDS[:max_lat])
    bottom = mercator_y(BRAZIL_MAP_BOUNDS[:min_lat])
    y = ((top - mercator_y(lat)) / (top - bottom)) * 100

    {
      x: x.clamp(3.0, 97.0).round(2),
      y: y.clamp(4.0, 96.0).round(2)
    }
  end

  def spread_clustered_map_points(points)
    points.group_by { |point| [point[:x].round, point[:y].round] }.values.flat_map do |cluster|
      next cluster if cluster.one?

      center_x = cluster.sum { |point| point[:x].to_f } / cluster.size
      center_y = cluster.sum { |point| point[:y].to_f } / cluster.size
      cluster_size = cluster.size

      cluster.each_with_index.map do |point, index|
        offset = supplier_cluster_offset(index, cluster_size)
        point.merge(
          x: (center_x + offset[:x]).clamp(3.0, 97.0).round(2),
          y: (center_y + offset[:y]).clamp(4.0, 96.0).round(2),
          clustered: true
        )
      end
    end
  end

  def supplier_cluster_offset(index, cluster_size)
    ring_index = index % 8
    ring = (index / 8) + 1
    angle = ((2 * Math::PI * ring_index) / [cluster_size, 8].min) - (Math::PI / 2)
    radius = case cluster_size
             when 2 then 0.9
             when 3..5 then 1.25
             when 6..8 then 1.7
             else 1.55 + (ring * 0.65)
             end

    {
      x: Math.cos(angle) * radius,
      y: Math.sin(angle) * radius
    }
  end

  def mercator_y(lat)
    radians = lat * Math::PI / 180
    Math.log(Math.tan((Math::PI / 4) + (radians / 2)))
  end
end
