require "test_helper"

class ApplicationHelperTest < ActionView::TestCase
  test "renders Font Awesome icons for workspace navigation" do
    icon = workspace_icon(:validation)

    assert_includes icon, "fa-solid"
    assert_includes icon, "fa-layer-group"
    assert_not_includes icon, "<svg"
  end

  test "renders status as an icon only, with an accessible label" do
    completed = workspace_status_tag("completed")
    processing = workspace_status_tag("processing")

    assert_includes completed, "fa-circle-check"
    assert_includes completed, "workspace-status--icon-only"
    assert_includes completed, 'aria-label="Concluído"'
    assert_not_includes completed, ">Concluído<"
    assert_includes processing, "fa-spinner"
    assert_includes processing, "fa-spin"
    assert_includes workspace_status_tag("error"), "fa-circle-xmark"
    assert_includes workspace_status_tag("pending"), "fa-clock"

    assert_includes workspace_status_tag("concluido"), "fa-circle-check"
    assert_includes workspace_status_tag("processando"), "fa-spinner"
    assert_includes workspace_status_tag("erro"), "fa-circle-xmark"
    assert_includes workspace_status_tag("pendente"), "fa-clock"
  end
end
