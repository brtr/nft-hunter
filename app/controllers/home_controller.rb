class HomeController < ApplicationController
  def extensions
    @page_index = 4
  end

  def not_permitted
    render json: {message: helpers.error_msgs(params[:error_code])}
  end

  def qanda
    @page_index = 6
  end

  def mint
    @page_index = 7
  end
end
