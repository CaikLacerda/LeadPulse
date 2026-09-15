require "test_helper"

module SupplierImports
  class AnonymizeEvidenceServiceTest < ActiveSupport::TestCase
    test "removes transcripts recordings and sensitive observations locally" do
      user = User.create!(
        name: "LeadPulse Operação",
        email: "anonymize-import@example.com",
        password: "Password123!",
        password_confirmation: "Password123!"
      )
      supplier_import = user.supplier_imports.create!(
        status: SupplierImport::LOCAL_STATUS_COMPLETED,
        workflow_kind: SupplierImport::WORKFLOW_KIND_CADASTRAL,
        source: SupplierImport::SOURCE_UPLOAD,
        response_payload: {
          "records" => [
            {
              "external_id" => "1",
              "transcript_summary" => "conteúdo sensível",
              "customer_transcript" => "fala do cliente",
              "assistant_transcript" => "fala da agente",
              "conversation_turns" => [
                { "sequence" => 1, "role" => "user", "transcript" => "fala do cliente" }
              ],
              "observation" => "detalhe pessoal informado na chamada",
              "call_attempts" => [
                {
                  "recording_url" => "https://example.test/audio.mp3",
                  "transcript_summary" => "resumo sensível",
                  "conversation_turns" => [
                    { "sequence" => 1, "role" => "user", "transcript" => "resumo sensível" }
                  ]
                }
              ]
            }
          ]
        }
      )

      AnonymizeEvidenceService.new(
        user: user,
        supplier_import: supplier_import
      ).call

      record = supplier_import.reload.response_payload.fetch("records").first
      assert_nil record["transcript_summary"]
      assert_nil record["customer_transcript"]
      assert_nil record["assistant_transcript"]
      assert_empty record["conversation_turns"]
      assert_equal "Evidências de áudio/transcrição anonimizadas conforme política LGPD.", record["observation"]
      assert_nil record.dig("call_attempts", 0, "recording_url")
      assert_empty record.dig("call_attempts", 0, "conversation_turns")
      assert record["evidence_anonymized"]
    end

    test "rejects a batch that belongs to another account" do
      owner = User.create!(
        name: "Conta proprietária",
        email: "anonymize-owner@example.com",
        password: "Password123!",
        password_confirmation: "Password123!"
      )
      intruder = User.create!(
        name: "Outra conta",
        email: "anonymize-intruder@example.com",
        password: "Password123!",
        password_confirmation: "Password123!"
      )
      supplier_import = owner.supplier_imports.create!(
        status: SupplierImport::LOCAL_STATUS_COMPLETED,
        workflow_kind: SupplierImport::WORKFLOW_KIND_CADASTRAL,
        source: SupplierImport::SOURCE_UPLOAD
      )

      assert_raises ActiveRecord::RecordNotFound do
        AnonymizeEvidenceService.new(
          user: intruder,
          supplier_import: supplier_import
        ).call
      end
    end
  end
end
