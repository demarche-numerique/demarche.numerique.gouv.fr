# frozen_string_literal: true

FactoryBot.define do
  sequence(:user_email) { |n| "user#{n}@user.com" }
  factory :user do
    email { generate(:user_email) }
    password { '{My-$3cure-p4ssWord}' }
    confirmed_at { Time.zone.now }

    trait :active do
      last_sign_in_at { Time.zone.now }
    end
    trait :inactive do
      last_sign_in_at { nil }
    end

    trait :unconfirmed do
      confirmed_at { nil }
    end

    trait :with_strong_password do
      password { '{my-%s3cure[]-p4$$w0rd' }
    end

    trait :with_fci do
      france_connect_informations { [association(:france_connect_information)] }
    end

    trait :with_pci do
      pro_connect_informations { [association(:pro_connect_information)] }
    end

    trait :with_email_verified do
      email_verified_at { Time.zone.now }
    end
  end
end
