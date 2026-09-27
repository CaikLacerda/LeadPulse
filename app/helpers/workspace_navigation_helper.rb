module WorkspaceNavigationHelper
  SIDEBAR_COOKIE = "lp_sidebar".freeze

  # Grupos da sidebar. Cada item respeita as permissões já usadas pelos controllers.
  def workspace_nav_groups
    return [] unless current_user

    @workspace_nav_groups ||= [
      {
        title: nil,
        items: [
          workspace_nav_item(:home, "Visão geral", root_path, icon: :home, match: ->(path) { path == "/" })
        ]
      },
      {
        title: "Operação",
        items: [
          workspace_nav_item(:search, "Busca de fornecedores", supplier_discovery_searches_path, icon: :search),
          workspace_nav_item(:validation, "Lotes de validação", supplier_imports_path, icon: :validation),
          workspace_nav_item(:commercial, "Retornos comerciais", commercial_opportunities_path, icon: :handshake)
        ]
      },
      {
        title: "Análise",
        items: [
          (workspace_nav_item(:audit, "Auditoria de chamadas", validation_audits_path, icon: :audit) if current_membership.can_view_evidence?)
        ].compact
      },
      {
        title: "Administração",
        items: [
          (workspace_nav_item(:settings, "Configurações", company_platform_settings_path, icon: :settings,
            match: ->(path) { path.start_with?("/configuracoes") && !path.start_with?(lgpd_platform_settings_path) }) if current_membership.can_manage_settings?),
          (workspace_nav_item(:lgpd, "LGPD e privacidade", lgpd_platform_settings_path, icon: :shield,
            match: ->(path) { path.start_with?(lgpd_platform_settings_path) || path.start_with?("/lgpd") }) if current_membership.can_manage_settings? && current_membership.can_manage_lgpd?),
          workspace_nav_item(:developer_docs, "API para desenvolvedores", developer_docs_path, icon: :code)
        ].compact
      }
    ].reject { |group| group[:items].empty? }
  end

  def workspace_active_nav
    return @workspace_active_nav if defined?(@workspace_active_nav)

    path = request.path
    @workspace_active_nav = workspace_nav_groups.lazy.filter_map do |group|
      item = group[:items].find { |candidate| candidate[:match].call(path) }
      { group:, item: } if item
    end.first
  end

  def workspace_nav_active?(item)
    workspace_active_nav&.dig(:item, :key) == item[:key]
  end

  # Migalhas extras da página atual, ex.: workspace_breadcrumbs("LD-068").
  # Cada item pode ser um texto ou um par [texto, caminho].
  def workspace_breadcrumbs(*items)
    @workspace_breadcrumbs = items.flatten(1).compact
  end

  def workspace_breadcrumb_trail
    active = workspace_active_nav
    extra = Array(@workspace_breadcrumbs).map { |item| item.is_a?(Array) ? item : [ item, nil ] }
    trail = []

    if active
      trail << [ active[:group][:title], nil ] if active[:group][:title].present?
      trail << [ active[:item][:label], extra.any? ? active[:item][:path] : nil ]
    end

    trail + extra
  end

  def workspace_sidebar_collapsed?
    cookies[SIDEBAR_COOKIE] == "collapsed"
  end

  private

  def workspace_nav_item(key, label, path, icon:, match: nil)
    { key:, label:, path:, icon:, match: match || ->(current) { current.start_with?(path) } }
  end
end
