module SupplierDiscoverySearchesHelper
  STATUS_BADGE_CLASSES = {
    SupplierDiscoverySearch::LOCAL_STATUS_PENDING => "border-amber-200 bg-amber-50 text-amber-800",
    SupplierDiscoverySearch::LOCAL_STATUS_PROCESSING => "border-blue-200 bg-blue-50 text-blue-700",
    SupplierDiscoverySearch::LOCAL_STATUS_COMPLETED => "border-emerald-200 bg-emerald-50 text-emerald-700",
    SupplierDiscoverySearch::LOCAL_STATUS_ERROR => "border-red-200 bg-red-50 text-red-700"
  }.freeze

  def supplier_discovery_status_badge(search)
    label = t("supplier_discovery_searches.statuses.#{search.status}")
    classes = STATUS_BADGE_CLASSES.fetch(search.status, "border-slate-200 bg-slate-50 text-slate-600")

    content_tag(
      :span,
      workspace_status_icon(search.status),
      class: "workspace-status workspace-status--with-icon workspace-status--icon-only inline-flex items-center border #{classes}",
      title: label,
      aria: { label: label }
    )
  end
end
