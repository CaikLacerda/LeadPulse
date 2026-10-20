# Projeção local de uma execução do Ambiente de Simulação. A FastAPI executa e é a fonte da
# verdade; aqui guardamos o essencial para listar, isolar por empresa e abrir a tela ao vivo,
# que busca o estado completo (eventos, transcript, avaliação) direto da API.
class Simulation < ApplicationRecord
  include HasDisplayCode

  # Espelham os status da FastAPI (docs/simulations.md).
  STATUS_QUEUED = "queued".freeze
  STATUS_RUNNING = "running".freeze
  STATUS_COMPLETED = "completed".freeze
  STATUS_FAILED = "failed".freeze
  STATUS_CANCELLED = "cancelled".freeze
  STATUS_INTERRUPTED = "interrupted".freeze
  STATUSES = [
    STATUS_QUEUED,
    STATUS_RUNNING,
    STATUS_COMPLETED,
    STATUS_FAILED,
    STATUS_CANCELLED,
    STATUS_INTERRUPTED
  ].freeze
  ACTIVE_STATUSES = [ STATUS_QUEUED, STATUS_RUNNING ].freeze
  TERMINAL_STATUSES = (STATUSES - ACTIVE_STATUSES).freeze

  MODE_AI_VS_AI = "ai_vs_ai".freeze

  belongs_to :account
  belongs_to :created_by, class_name: "User", optional: true

  validates :remote_id, presence: true, length: { maximum: 120 }
  validates :mode, presence: true, length: { maximum: 24 }
  validates :target_type, presence: true, length: { maximum: 40 }
  validates :workflow_key, presence: true, length: { maximum: 80 }
  validates :scenario_key, presence: true, length: { maximum: 40 }
  validates :status, presence: true, inclusion: { in: STATUSES }

  scope :recent_first, -> { order(created_at: :desc) }
  scope :active, -> { where(status: ACTIVE_STATUSES) }

  display_code_prefix "SIM"

  def active?
    ACTIVE_STATUSES.include?(status)
  end

  def terminal?
    TERMINAL_STATUSES.include?(status)
  end

  def completed?
    status == STATUS_COMPLETED
  end

  # Atualiza a projeção local a partir de uma resposta da API (GET /simulations/{id}),
  # sem recriar a timeline de eventos, que permanece na FastAPI.
  def apply_remote_snapshot!(run)
    return if run.blank?

    assign_attributes(
      status: STATUSES.include?(run["status"]) ? run["status"] : status,
      call_result: run["call_result"],
      accuracy: run["accuracy"],
      raw_value_accuracy: run["raw_value_accuracy"],
      turn_count: run["turn_count"],
      duration_ms: run["duration_ms"],
      finished_at: ValidationApi::Timestamp.parse(run["finished_at"])
    )
    save! if changed?
  end
end
