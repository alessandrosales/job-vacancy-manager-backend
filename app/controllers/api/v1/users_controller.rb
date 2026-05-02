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
        params.require(:user).permit(:name, :email, :password, :password_confirmation)
      end

      def user_update_params
        permitted = params.require(:user).permit(:name, :email, :password, :password_confirmation)
        permitted.delete(:password) if permitted[:password].blank?
        permitted.delete(:password_confirmation) if permitted[:password_confirmation].blank?
        permitted
      end
    end
  end
end
