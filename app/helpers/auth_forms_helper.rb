# Erros de campo nas telas de autenticação: a mensagem do backend aparece junto ao campo e fica
# ligada ao input por aria-describedby. O texto das mensagens não muda.
module AuthFormsHelper
  def auth_field_error_id(resource, attribute)
    "#{resource.model_name.param_key}_#{attribute}_error"
  end

  def auth_field_error(resource, attribute)
    messages = resource.errors.full_messages_for(attribute)
    return if messages.empty?

    tag.p(id: auth_field_error_id(resource, attribute), class: "auth-field-error") do
      safe_join([ tag.i(class: "fa-solid fa-circle-exclamation", aria: { hidden: true }), tag.span(safe_join(messages, tag.br)) ])
    end
  end

  # Atributos aria do input: aria-invalid quando há erro e aria-describedby com a dica e o erro.
  def auth_field_aria(resource, attribute, hint: nil)
    invalid = resource.errors.include?(attribute)
    describedby = [ hint, (auth_field_error_id(resource, attribute) if invalid) ].compact.join(" ")
    { invalid: (true if invalid), describedby: describedby.presence }.compact
  end
end
