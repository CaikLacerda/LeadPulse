# Mocka a camada ValidationApi::Simulations::* nos testes do Rails, sem bater na FastAPI e sem
# depender de gem de mock. Troca temporariamente o método #call de cada service por um bloco
# que devolve o valor combinado (ou levanta, quando o valor é uma exceção/lambda).
module SimulationApiStub
  SERVICES = {
    catalog: "ValidationApi::Simulations::CatalogService",
    create: "ValidationApi::Simulations::CreateService",
    show: "ValidationApi::Simulations::ShowService",
    events: "ValidationApi::Simulations::EventsService",
    cancel: "ValidationApi::Simulations::CancelService"
  }.freeze

  # Uso: stub_simulation_api(show: {...}, events: {...}) { get ... }
  # Valor pode ser um Hash (retorno), um Exception (levantado) ou um callable.
  def stub_simulation_api(stubs)
    originals = {}

    stubs.each do |name, value|
      klass = SERVICES.fetch(name).constantize
      originals[klass] = klass.instance_method(:call)
      klass.define_method(:call) do |*_args, **_kwargs|
        case value
        when Exception then raise value
        when Proc then value.call
        else value
        end
      end
    end

    yield
  ensure
    originals&.each { |klass, method| klass.define_method(:call, method) }
  end
end
