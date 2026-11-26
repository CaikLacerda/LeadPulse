# Estado da requisição ou do job atual. request_id vai no header X-Request-ID das chamadas à
# API de validação, que o usa nos próprios logs: o mesmo id liga as duas aplicações.
class Current < ActiveSupport::CurrentAttributes
  attribute :request_id
end
