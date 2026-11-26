class AccountInvitationMailer < ApplicationMailer
  def invite(invitation, token)
    @invitation = invitation
    @company = invitation.account.validation_company_name_value
    @inviter = invitation.invited_by&.name
    @url = invitation_url(token)

    mail to: invitation.email, subject: "Convite para a equipe de #{@company} no LeadPulse"
  end
end
