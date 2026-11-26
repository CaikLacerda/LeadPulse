# Projeção local do Ambiente de Simulação. A FastAPI é a fonte da verdade da execução;
# o Rails guarda o suficiente para listar o histórico, isolar por empresa e saber quem iniciou.
class CreateSimulations < ActiveRecord::Migration[8.0]
  def change
    create_table :simulations do |t|
      t.references :account, null: false, foreign_key: true, index: true
      # Autoria opcional: a empresa é a dona; quem iniciou pode deixar de existir.
      t.references :created_by, null: true, foreign_key: { to_table: :users, on_delete: :nullify }

      # Identificador remoto da execução na FastAPI (simulation_id).
      t.string :remote_id, null: false, limit: 120
      t.string :mode, null: false, limit: 24
      t.string :target_type, null: false, limit: 40, default: "system_workflow"
      t.string :workflow_key, null: false, limit: 80
      t.string :scenario_key, null: false, limit: 40
      t.string :status, null: false, limit: 24, default: "queued"

      # Resultado final espelhado quando a execução termina (para a listagem).
      t.string :call_result, limit: 40
      t.float :accuracy
      t.float :raw_value_accuracy
      t.integer :turn_count
      t.integer :duration_ms
      t.datetime :finished_at

      t.timestamps
    end

    add_index :simulations, [ :account_id, :created_at ]
    add_index :simulations, [ :account_id, :remote_id ], unique: true
  end
end
