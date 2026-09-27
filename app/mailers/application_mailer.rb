class ApplicationMailer < ActionMailer::Base
  default from: ENV.fetch("MAILER_FROM", "LeadPulse <nao-responda@leadpulse.local>")
  layout "mailer"
end
