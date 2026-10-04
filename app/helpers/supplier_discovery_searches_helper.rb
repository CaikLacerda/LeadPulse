module SupplierDiscoverySearchesHelper
  def supplier_discovery_status_badge(search)
    label = t("supplier_discovery_searches.statuses.#{search.status}", default: local_status_label(search.status))

    status_badge(
      label,
      tone: workspace_status_tone(search.status),
      pulse: ApplicationHelper::PULSING_STATUSES.include?(search.status.to_s),
      icon: workspace_status_icon(search.status)
    )
  end
end
