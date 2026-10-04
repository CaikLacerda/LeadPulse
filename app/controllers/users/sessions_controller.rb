module Users
  class SessionsController < Devise::SessionsController
    include AuthenticationThrottle
  end
end
