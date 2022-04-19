module ApplicationHelper
  def current_user
    @current_user ||= User.find_by(id: session[:user_id])
  end

  def is_admin?
    admin_ids = ENV.fetch("ADMIN_IDS"){""}.split(',')
    current_user && current_user.id.to_s.in?(admin_ids)
  end

  def address_format(address)
    address[6...-4] = "...."
    address
  end

  def decimal_format(data)
    data.to_f.round(3)
  end
end
