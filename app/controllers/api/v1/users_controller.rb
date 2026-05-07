module Api
  module V1
    class UsersController < AuthenticatedController
      skip_before_action :authenticate_request!, only: :create

      before_action :set_user, only: %i[ show update destroy ]

      def index
        render_paginated(User.where(id: current_user.id))
      end

      def show
        render json: @user.as_api_json
      end

      def create
        user = User.new(user_params)
        if user.save
          render json: user.as_api_json, status: :created
        else
          render json: { errors: user.errors.as_json }, status: :unprocessable_entity
        end
      end

      def update
        if @user.update(user_update_params)
          if @user.previous_changes.key?("password_digest")
            PasswordMailer.with(user: @user).password_changed.deliver_now
          end
          render json: @user.as_api_json
        else
          render json: { errors: @user.errors.as_json }, status: :unprocessable_entity
        end
      end

      def destroy
        @user.destroy!
        head :no_content
      end

      private

      def set_user
        @user = User.find_by(id: params[:id])
        head(:not_found) && return if @user.blank?
        head(:forbidden) && return unless @user.id == current_user.id
      end

      def user_params
        permitted = params.require(:user).permit(
          :name, :email, :password, :password_confirmation,
          :phone, :avatar_url, :bio, :age, :full_address, :relationship_status, :gender,
          :preferred_language
        )
        permitted[:age] = nil if permitted.key?(:age) && permitted[:age].to_s.strip.empty?
        permitted
      end

      def user_update_params
        permitted = params.require(:user).permit(
          :name, :email, :password, :password_confirmation,
          :phone, :avatar_url, :bio, :age, :full_address, :relationship_status, :gender,
          :preferred_language,
          :ai_token
        )
        permitted.delete(:password) if permitted[:password].blank?
        permitted.delete(:password_confirmation) if permitted[:password_confirmation].blank?
        permitted[:age] = nil if permitted.key?(:age) && permitted[:age].to_s.strip.empty?
        if permitted.key?(:ai_token)
          permitted[:ai_token] = permitted[:ai_token].to_s.strip.presence
        end
        permitted
      end
    end
  end
end
