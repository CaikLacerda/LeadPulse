module ValidationApi
  class Error < StandardError
    attr_reader :status_code, :response_body, :details

    def initialize(message, status_code: nil, response_body: nil, details: nil)
      super(message)
      @status_code = status_code
      @response_body = response_body
      @details = details
    end
  end
end
