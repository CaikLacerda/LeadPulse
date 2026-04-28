module PaginatesCollection
  extend ActiveSupport::Concern

  DEFAULT_PER_PAGE = 5

  private

  def paginate_collection(scope, page_param:, per_page: DEFAULT_PER_PAGE)
    total_count = scope.count
    total_pages = [(total_count.to_f / per_page).ceil, 1].max
    current_page = normalized_page(page_param, total_pages)
    paginated_scope = scope.offset((current_page - 1) * per_page).limit(per_page)

    {
      records: paginated_scope,
      total_count: total_count,
      total_pages: total_pages,
      current_page: current_page
    }
  end

  def paginate_array(records, page_param:, per_page: DEFAULT_PER_PAGE)
    total_count = records.size
    total_pages = [(total_count.to_f / per_page).ceil, 1].max
    current_page = normalized_page(page_param, total_pages)
    offset = (current_page - 1) * per_page

    {
      records: records.slice(offset, per_page) || [],
      total_count: total_count,
      total_pages: total_pages,
      current_page: current_page
    }
  end

  def normalized_page(page_param, total_pages)
    page = page_param.to_i
    page = 1 if page < 1
    [page, total_pages].min
  end
end
