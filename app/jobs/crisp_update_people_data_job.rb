# frozen_string_literal: true

class CrispUpdatePeopleDataJob < ApplicationJob
  include Dry::Monads[:result]

  discard_on ActiveRecord::RecordNotFound

  queue_as :default

  def perform(session_id, email)
    meta = fetch_conversation_meta(session_id)
    email ||= meta[:email]
    user = User.find_by!(email:)

    update_people_data(user)
    update_conversation(session_id, user, meta[:segments])
  end

  private

  def fetch_conversation_meta(session_id)
    result = Crisp::APIService.new.get_conversation_meta(session_id:)
    case result
    in Success(data:)
      { email: data[:email], segments: data[:segments] || [] }
    in Failure(error:)
      fail error
    end
  end

  def update_people_data(user)
    user_data = Crisp::UserDataBuilder.new(user).build_data
    result = Crisp::APIService.new.update_people_data(email: user.email, body: { data: user_data })

    case result
    in Success
    # NOOP
    in Failure(error:)
      fail error
    end
  end

  def update_conversation(session_id, user, existing_segments)
    segments = Set.new(existing_segments + user.crisp_segments)
    return if segments == Set.new(existing_segments)

    Crisp::APIService.new.update_conversation_meta(session_id:, body: { segments: })
  end
end
