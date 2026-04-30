# frozen_string_literal: true

FactoryBot.define do
  factory :email_event do
    to { "user@email.com" }
    subject { "Thank you" }
    processed_at { Time.zone.now }
    status { "dispatched" }
    add_attribute(:method) { "brevo" }
  end
end
