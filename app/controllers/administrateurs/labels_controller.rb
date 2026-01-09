# frozen_string_literal: true

module Administrateurs
  class LabelsController < AdministrateurController
    before_action :retrieve_procedure
    before_action :retrieve_label, only: [:edit, :update, :destroy]
    before_action :set_colors_collection, only: [:edit, :new, :create, :update]

    def index
      @labels = @procedure.labels
    end

    def edit
      @labels = @procedure.labels
    end

    def new
      @labels = @procedure.labels
      @label = Label.new
    end

    def create
      @label = @procedure.labels.build(label_params)

      if @label.save
        flash.notice = 'Le label a bien été créé'
        redirect_to [:admin, @procedure, :labels]
      else
        flash.alert = @label.errors.full_messages
        render :new
      end
    end

    def update
      if @label.update(label_params)
        flash.notice = 'Le label a bien été modifié'
        redirect_to [:admin, @procedure, :labels]
      else
        flash.alert = @label.errors.full_messages
        render :edit
      end
    end

    def destroy
      @label.destroy!
      flash.notice = 'Le label a bien été supprimé'
      redirect_to [:admin, @procedure, :labels]
    end

    def order_positions
      @labels = @procedure.labels
      render layout: "empty_layout"
    end

    def update_order_positions
      @procedure.update_labels_position(ordered_label_ids_params)
      redirect_to admin_procedure_labels_path, notice: "L’ordre des labels a été mis à jour."
    end

    private

    def label_params
      params.require(:label).permit(:name, :color)
    end

    def ordered_label_ids_params
      params.require(:ordered_label_ids)
    end

    def retrieve_label
      @label = @procedure.labels.find(params[:id])
    end

    def set_colors_collection
      @colors_collection = Label.colors.keys
    end
  end
end
