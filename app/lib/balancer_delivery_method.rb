# frozen_string_literal: true

# A Mail delivery method that randomly balances the actual delivery between different
# methods.
#
# Usage:
#
# ```ruby
#   ActionMailer::Base.add_delivery_method :balancer, BalancerDeliveryMethod
#   config.action_mailer.balancer_settings = {
#     smtp: 25,
#     sendmail: 75
#   }
#   config.action_mailer.delivery_method = :balancer
# ```
#
# Be sure to restart your server when you modify this file.
class BalancerDeliveryMethod
  BYPASS_UNVERIFIED_MAIL_PROTECTION = 'BYPASS_UNVERIFIED_MAIL_PROTECTION'
  FORCE_DELIVERY_METHOD_HEADER = 'X-deliver-with'
  CRITICAL_HEADER = 'x-critical'
  BREVO_API_FEATURE = :brevo_api_delivery
  # Allows configuring the random number generator used for selecting a delivery method,
  # mostly for testing purposes.
  mattr_accessor :random, default: Random.new

  def initialize(settings)
    @delivery_methods = settings
  end

  def deliver!(mail)
    return if prevent_delivery?(mail)

    balanced_delivery_method = delivery_method(mail)
    ApplicationMailer.wrap_delivery_behavior(mail, balanced_delivery_method)

    # Because we don't want to invoke observers or interceptors twice,
    # we can't call again `mail.deliver` here to send the email with balanced method
    # (it was first called before by deliver_now in ActiveJob or application code, which leads us here).
    #
    # Instead, we directly deliver the email from the handler (set by the wrapper above)
    # like Mail::Message.deliver does.
    #
    # See https://github.com/mikel/mail/blob/199a76bed3fc518508b46135691914a1cfd8bff8/lib/mail/message.rb#L250
    mail.delivery_handler.deliver_mail(mail) { mail.send :do_delivery }
  end

  private

  def prevent_delivery?(mail)
    return false if mail[BYPASS_UNVERIFIED_MAIL_PROTECTION].present?
    return false if mail[CRITICAL_HEADER].present?
    return false if mail.to.blank? # bcc list

    user = User.find_by(email: mail.to.first)
    return true if user.email_unsubscribed? if user.present?
    return user.unverified_email? if user.present?

    individual = Individual.find_by(email: mail.to.first)
    return individual.unverified_email? if individual.present?

    true
  end

  def force_delivery_method?(mail)
    @delivery_methods.keys.map(&:to_s).include?(mail[FORCE_DELIVERY_METHOD_HEADER]&.value)
  end

  def delivery_method(mail)
    return mail[FORCE_DELIVERY_METHOD_HEADER].value.to_sym if force_delivery_method?(mail)
    return :brevo_api if brevo_api_enabled_for?(mail)

    @delivery_methods
      .flat_map { |delivery_method, weight| [delivery_method] * weight }
      .sample(random: self.class.random)
  end

  def brevo_api_enabled_for?(mail)
    return false if !@delivery_methods.key?(:brevo_api) || mail.to.blank?

    Flipper.enabled?(BREVO_API_FEATURE, User.find_by(email: mail.to.first))
  end
end
