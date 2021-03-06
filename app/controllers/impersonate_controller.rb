class ImpersonateController < ApplicationController
  def action_allowed?
    ['Super-Administrator',
     'Administrator',
     'Instructor',
     'Teaching Assistant'].include? current_role_name
  end

  def auto_complete_for_user_name
    @users = session[:user].get_available_users(params[:user][:name])
    render inline: "<%= auto_complete_result @users, 'name' %>", layout: false
  end

  def start
    if !request.GET.empty?
      flash[:error] = "This page doesn't take any query string."
    end
  end

  def impersonate
    special_chars_handler = SecurityHelper::SpecialCharsHandler.new
    if special_chars_handler.contains_special_chars?(params[:user]) || special_chars_handler.contains_special_chars?(params[:user][:name])
      flash[:error] = "Username must not contain " + special_chars_handler.special_chars
      redirect_back
      return
    end
    if params[:user] && params[:user][:name]
      message = "No user exists with the name '#{params[:user][:name]}'."
    end
    begin
      original_user = session[:super_user] || session[:user]
      # Impersonate using form on /impersonate/start
      if params[:impersonate].nil?
        user = User.find_by(name: params[:user][:name])
        if user
          unless original_user.can_impersonate? user
            flash[:error] = "You cannot impersonate #{params[:user][:name]}."
            redirect_back
            return
          end
          session[:super_user] = session[:user] if session[:super_user].nil?
          AuthController.clear_user_info(session, nil)
          session[:user] = user
        else
          flash[:error] = message
          redirect_back
          return
        end
      else
        # Impersonate a new account
        if !params[:impersonate][:name].empty?
          user = User.find_by(name: params[:impersonate][:name])
          if user
            unless original_user.can_impersonate? user
              flash[:error] = "You cannot impersonate #{params[:user][:name]}."
              redirect_back
              return
            end
            AuthController.clear_user_info(session, nil)
            session[:user] = user
          else
            flash[:error] = message
            redirect_back
            return
          end
          # Revert to original account
        else
          if !session[:super_user].nil?
            AuthController.clear_user_info(session, nil)
            session[:user] = session[:super_user]
            user = session[:user]
            session[:super_user] = nil
          else
            flash[:error] = "No original account was found. Please close your browser and start a new session."
            redirect_back
            return
          end
        end
      end
      # Navigate to user's home location
      AuthController.set_current_role(user.role_id, session)
      redirect_to action: AuthHelper.get_home_action(session[:user]),
                  controller: AuthHelper.get_home_controller(session[:user])
    rescue Exception => e
      flash[:error] = e.message
      redirect_to :back
    end
  end
end
