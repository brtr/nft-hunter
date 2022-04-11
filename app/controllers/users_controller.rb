class UsersController < ApplicationController
  def login
    user = User.where(address: params[:address]).first_or_create
    session[:user_id] = user.id

    render json: {success: true}
  end

  def logout
    session[:user_id] = nil if session[:user_id]

    render json: {success: true}
  end
end
