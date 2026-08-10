# frozen_string_literal: true

module CommentaireHelper
  def commentaire_is_from_me_class(commentaire, connected_user)
    if commentaire.sent_by?(connected_user)
      "from-me"
    end
  end

  def commentaire_answer_action(commentaire, connected_user)
    if commentaire.sent_by?(connected_user)
      t('helpers.commentaire.send_message_to_instructeur')
    else
      t('helpers.commentaire.reply_in_mailbox')
    end
  end

  def grouped_commentaires_by_date(commentaires)
    commentaires.group_by { |commentaire| commentaire.created_at.to_date }
  end
end
