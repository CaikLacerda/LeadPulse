module Users
  class PasswordsController < Devise::PasswordsController
    include AuthenticationThrottle
  end
end
