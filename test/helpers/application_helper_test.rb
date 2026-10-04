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
    assert_includes workspace_status_tag("pendente"), "workspace-status--warning"
    assert_includes workspace_status_tag("cancelled"), "workspace-status--neutral"
  end

  test "pairs each status label with an icon that carries its meaning" do
    assert_includes workspace_status_tag("pendente"), "fa-clock"
    assert_includes workspace_status_tag("concluido"), "fa-circle-check"
    assert_includes workspace_status_tag("erro"), "fa-circle-xmark"
    assert_includes workspace_status_tag("cancelled"), "fa-circle-minus"
    assert_includes audit_result_tag("inconclusive"), "fa-circle-exclamation"
    assert_includes status_badge("Ativo", tone: :success), "fa-circle-check"
    assert_includes status_badge("Pendente", tone: :info, icon: "fa-clock"), "fa-clock"
    assert_match(/<i[^>]*aria-hidden="true"/, workspace_status_tag("concluido"))
  end

  test "shows statuses as icons only, keeping the label for screen readers and the tooltip" do
    completed = workspace_status_tag("concluido")

    assert_includes completed, 'title="Concluído"'
    assert_match(/class="sr-only">Concluído</, completed)
    assert_includes status_badge("Recusa LGPD", tone: :danger, show_label: true), 'class="workspace-status__label">Recusa LGPD<'
  end

  test "marks processing statuses with a spinning indicator" do
    processing = workspace_status_tag("processando")

    assert_includes processing, "workspace-status--info"
    assert_includes processing, "workspace-status--pulse"
    assert_includes processing, "fa-circle-notch"
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
