require "test_helper"

class ApplicationHelperTest < ActionView::TestCase
  test "renders Font Awesome icons for workspace navigation" do
    icon = workspace_icon(:validation)

    assert_includes icon, "fa-solid"
    assert_includes icon, "fa-layer-group"
    assert_not_includes icon, "<svg"
  end

  test "renders status as a badge with a visible label and a semantic tone" do
    completed = workspace_status_tag("concluido")

    assert_includes completed, "workspace-status--success"
    assert_includes completed, ">Concluído<"
    assert_includes workspace_status_tag("erro"), "workspace-status--danger"
    assert_includes workspace_status_tag("pendente"), "workspace-status--neutral"
  end

  test "marks processing statuses with a pulsing indicator" do
    processing = workspace_status_tag("processando")

    assert_includes processing, "workspace-status--info"
    assert_includes processing, "workspace-status--pulse"
    assert_not_includes workspace_status_tag("concluido"), "workspace-status--pulse"
  end

  test "translates remote statuses to the local labels" do
    assert_includes workspace_status_tag("completed"), ">Concluído<"
    assert_includes workspace_status_tag("processing"), ">Processando<"
    assert_includes workspace_status_tag("failed"), ">Erro<"
    assert_includes workspace_status_tag("pending"), ">Pendente<"
  end

  test "keeps audit results distinguishable by tone" do
    assert_includes audit_result_tag("confirmed_by_call"), "workspace-status--success"
    assert_includes audit_result_tag("inconclusive"), "workspace-status--warning"
    assert_includes audit_result_tag("not_answered"), "workspace-status--warning"
    assert_includes audit_result_tag("wrong_company"), "workspace-status--danger"
    assert_includes audit_result_tag(nil), "workspace-status--neutral"
  end
end
