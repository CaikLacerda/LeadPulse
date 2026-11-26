import { Controller } from "@hotwired/stimulus"

// Tela "nova simulação": mostra só os cenários do workflow escolhido, mantém o target_type
// coerente e espelha a escolha no resumo técnico/barra de execução. Toda a lista vem do
// servidor (catálogo da API); aqui só se filtra e se reflete — o POST não muda.
export default class extends Controller {
  static targets = [
    "workflow", "scenario", "scenarioOption", "targetType",
    "workflowSummary", "scenarioSummary", "expectedOutcome"
  ]

  connect() {
    const selected = this.workflowTargets.find((input) => input.checked) || this.workflowTargets[0]
    if (selected) this.applyWorkflow(selected.value, selected.dataset.targetType)
    this.refreshSummary()
  }

  selectWorkflow(event) {
    this.applyWorkflow(event.target.value, event.target.dataset.targetType)
    this.refreshSummary()
  }

  selectScenario() {
    this.refreshSummary()
  }

  applyWorkflow(workflowKey, targetType) {
    if (this.hasTargetTypeTarget && targetType) this.targetTypeTarget.value = targetType

    this.scenarioOptionTargets.forEach((option) => {
      const belongs = option.dataset.workflow === workflowKey
      option.hidden = !belongs
    })

    // Garante um cenário selecionado dentro do workflow visível.
    const visible = this.scenarioTargets.filter((input) => input.dataset.workflow === workflowKey)
    if (visible.length && !visible.some((input) => input.checked)) visible[0].checked = true

    // Desmarca cenários de workflows escondidos para não enviar valor inválido.
    this.scenarioTargets
      .filter((input) => input.dataset.workflow !== workflowKey)
      .forEach((input) => { input.checked = false })
  }

  // Apresentação: espelha workflow, cenário e resultado esperado no resumo e na barra de execução.
  refreshSummary() {
    const workflow = this.workflowTargets.find((input) => input.checked)
    const scenario = this.scenarioTargets.find((input) => input.checked && !input.closest("[hidden]"))

    if (workflow && this.hasWorkflowSummaryTarget) this.workflowSummaryTarget.textContent = workflow.dataset.label || workflow.value
    if (scenario && this.hasScenarioSummaryTarget) this.scenarioSummaryTarget.textContent = scenario.dataset.label || scenario.value
    if (scenario && this.hasExpectedOutcomeTarget) this.expectedOutcomeTarget.textContent = scenario.dataset.outcome || ""
  }
}
