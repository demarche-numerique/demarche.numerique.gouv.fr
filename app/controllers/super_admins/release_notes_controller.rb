# frozen_string_literal: true

class SuperAdmins::ReleaseNotesController < ApplicationController
  include RequiresEnrolledSuperAdminOtp

  before_action :authenticate_super_admin!
  before_action :set_note, only: [:edit, :update, :destroy]

  def nav_bar_profile
    :superadmin
  end

  def index
    @release_notes = ReleaseNote
      .order(released_on: :desc, id: :asc)
      .with_rich_text_body
  end

  def show
    # allows refreshing a submitted page in error
    redirect_to edit_super_admins_release_note_path(params[:id])
  end

  def new
    @release_note = ReleaseNote.new(released_on: params[:date].presence || Date.current, published: true)
  end

  def create
    @release_note = ReleaseNote.new(release_note_params)
    if @release_note.save
      redirect_to edit_super_admins_release_note_path(@release_note), notice: t('.success')
    else
      flash.now[:alert] = [t('.error'), @release_note.errors.full_messages].flatten
      render :new, status: :unprocessable_content
    end
  end

  def edit
    @release_note = ReleaseNote.find(params[:id])
  end

  def update
    if @release_note.update(release_note_params)
      redirect_to edit_super_admins_release_note_path(@release_note), notice: t('.success')
    else
      flash.now[:alert] = [t('.error'), @release_note.errors.full_messages].flatten
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    @release_note.destroy!

    redirect_to super_admins_release_notes_path, notice: t('.success')
  end

  private

  def release_note_params
    params.require(:release_note).permit(:released_on, :published, :body, categories: [])
  end

  def set_note
    @release_note = ReleaseNote.find(params[:id])
  end
end
