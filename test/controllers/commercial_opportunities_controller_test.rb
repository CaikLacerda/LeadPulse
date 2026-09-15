require "test_helper"

class CommercialOpportunitiesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @password = "Password123!"
    @user = User.create!(
      name: "Operação Comercial",
      email: "comercial@example.com",
      password: @password,
      password_confirmation: @password
    )
    supplier_import = @user.supplier_imports.create!(
      status: SupplierImport::LOCAL_STATUS_COMPLETED,
      workflow_kind: SupplierImport::WORKFLOW_KIND_SUPPLIER,
      source: SupplierImport::SOURCE_UPLOAD
    )
    @opportunity = @user.commercial_opportunities.create!(
      supplier_import: supplier_import,
      source_external_id: "supplier-1",
      supplier_name: "Fornecedor Exemplo",
      callback_phone: "+5511987654321",
      callback_phone_choice: "same_number",
      callback_preferred_time: "Período da manhã"
    )
  end

  test "redirects guests to sign in" do
    get commercial_opportunities_url

    assert_redirected_to new_user_session_path
  end

  test "renders the separate commercial queue" do
    sign_in

    get commercial_opportunities_url

    assert_response :success
    assert_select "h1", text: "Retornos comerciais"
    assert_match "Fornecedor Exemplo", @response.body
    assert_match "Período da manhã", @response.body
    assert_select ".app-notifications", count: 1
    assert_select ".app-notification-badge", text: "1"
    assert_select ".app-notification-item", text: /Retornos comerciais pendentes/
  end

  test "renders collected commercial details" do
    @opportunity.update!(
      status: CommercialOpportunity::STATUS_COMPLETED,
      result_ready: true,
      product_specification: "Chapa galvanizada 2 mm",
      unit_price: "R$ 120 por chapa",
      lot_price_ranges: "R$ 110 acima de 50 chapas",
      minimum_order: "10 chapas",
      outcome: "collected"
    )
    sign_in

    get commercial_opportunity_url(@opportunity)

    assert_response :success
    assert_match "Chapa galvanizada 2 mm", @response.body
    assert_match "R$ 120 por chapa", @response.body
    assert_match "10 chapas", @response.body
  end

  test "json sync reports terminal state for automatic page reconciliation" do
    @user.update!(validation_api_token: "lp_test_token")
    @opportunity.update!(
      status: CommercialOpportunity::STATUS_PROCESSING,
      remote_batch_id: "commercial-json-sync",
      remote_batch_status: "processing",
      started_at: 5.minutes.ago
    )
    sign_in

    fake_service = Object.new
    fake_service.define_singleton_method(:call) do
      @opportunity.update!(
        status: CommercialOpportunity::STATUS_COMPLETED,
        remote_batch_status: "completed",
        result_ready: true
      )
    end
    fake_service.instance_variable_set(:@opportunity, @opportunity)
    service_class = CommercialOpportunities::SyncRemoteStatusService
    original_constructor = service_class.method(:new)
    service_class.define_singleton_method(:new) { |**| fake_service }

    begin
      post sync_status_commercial_opportunity_url(@opportunity, format: :json)
    ensure
      service_class.define_singleton_method(:new, original_constructor)
    end

    assert_response :success
    payload = JSON.parse(response.body)
    assert_equal CommercialOpportunity::STATUS_COMPLETED, payload["status"]
    assert_equal true, payload["changed"]
    assert_equal true, payload["terminal"]
  end

  test "invalid start request does not regress a completed opportunity" do
    @opportunity.update!(
      status: CommercialOpportunity::STATUS_COMPLETED,
      result_ready: true,
      remote_batch_status: "completed"
    )
    sign_in

    service_class = CommercialOpportunities::StartRemoteValidationService
    original_constructor = service_class.method(:new)
    failing_service = Object.new
    failing_service.define_singleton_method(:call) do
      raise ValidationApi::Error, "Este retorno comercial não está disponível para início."
    end
    service_class.define_singleton_method(:new) { |**| failing_service }

    begin
      post start_commercial_opportunity_url(@opportunity)
    ensure
      service_class.define_singleton_method(:new, original_constructor)
    end

    assert_redirected_to commercial_opportunities_url
    assert_equal CommercialOpportunity::STATUS_COMPLETED, @opportunity.reload.status
    assert @opportunity.result_ready?
  end

  private

  def sign_in
    post user_session_url, params: {
      user: { email: @user.email, password: @password }
    }
  end
end
