# Filters added to this controller apply to all controllers in the application.
# Likewise, all the methods added will be available for all controllers.

class ApplicationController < ActionController::Base

  if AppConfig.exception_notification['activate']
    include ExceptionNotifiable
    include SuperExceptionNotifier
    include ExceptionNotifierHelper
    self.error_layout = 'application'
    local_addresses.clear

    exception_data :additional_data
    def additional_data
      { :group => find_group}
    end
    protected :additional_data
  else

    # This method is override from Rails API
    # so see if allways works in next Rails version
    def render_optional_error_file(status_code)
      status = interpret_status(status_code)
      render "error/#{status[0,3]}"
    end
  end

  include AuthenticatedSystem
  include Subdomains

  protect_from_forgery

  before_filter :find_group
  before_filter :check_group_access
  before_filter :find_languages
  before_filter :set_locale
  layout 'application'

  protected

  def access_denied
    store_location
    if logged_in?
      flash[:error] = t("global.permission_denied")
    else
      flash[:error] = t("global.please_login")
    end
    redirect_to login_path
  end

  def check_group_access
    if @current_group &&
       (@current_group.private && (!logged_in? || !current_user.user_of?(@current_group)))
      access_denied
    end
  end

  def find_group
    @current_group ||= begin
      subdomains = request.subdomains
      subdomains.delete("www") if request.host == "www.#{AppConfig.domain}"
      _current_group = Group.first(:state => "active", :domain => request.host)
      unless _current_group
        flash[:warn] = t("global.group_not_found", :url => request.host)
        redirect_to domain_url(:custom => AppConfig.domain)
        return
      end
      _current_group
    end
    @current_group
  end

  def current_group
    @current_group
  end
  helper_method :current_group

  def current_tags
    @current_tags ||=  if params[:tags].kind_of?(String)
      params[:tags].split("+")
    elsif params[:tags].kind_of?(Array)
      params[:tags]
    else
      []
    end
  end
  helper_method :current_tags

  def current_languages
    @current_languages ||= find_languages.join("+")
  end
  helper_method :current_languages

  def find_languages
    @languages ||= begin
      if AppConfig.enable_i18n
        if languages = current_group.language
          languages = [languages]
        else
          if logged_in?
            languages = current_user.languages_to_filter
          else
            languages = [I18n.locale.to_s.split("-").first]
          end
        end
        languages
      else
        [current_group.language || AppConfig.default_language]
      end
    end
  end
  helper_method :find_languages

  def language_conditions
    conditions = {}
    conditions[:language] = { :$in => find_languages}
    conditions
  end
  helper_method :language_conditions

  def scoped_conditions(conditions = {})
    unless current_tags.empty?
      conditions.deep_merge!({:tags => {:$all => current_tags}})
    end
    conditions.deep_merge!({:group_id => current_group.id})
    conditions.deep_merge!(language_conditions)
  end
  helper_method :scoped_conditions

  def available_locales; AVAILABLE_LOCALES; end

  def set_locale
    locale = AppConfig.default_language || 'en'
    if logged_in?
      locale = current_user.language
      Time.zone = current_user.timezone || "UTC"
    elsif params[:lang] =~ /^(\w\w)/
      locale = find_valid_locale($1)
    elsif !AppConfig.default_language
      if request.env['HTTP_ACCEPT_LANGUAGE'] =~ /^(\w\w)/
        locale = find_valid_locale($1)
      end
    end

    I18n.locale = locale.to_s
  end

  def find_valid_locale(lang)
    case lang
      when /^es/
        'es-AR'
      when /^pt/
        'pt-PT'
      when "fr"
        'fr'
      else
        'en'
    end
  end
  helper_method :find_valid_locale

  def set_page_title(title)
    @page_title = title
  end

  def page_title
    if @page_title
      if current_group.name == AppConfig.application_name
        "#{@page_title} - #{AppConfig.application_name}: #{t("layouts.application.title")}"
      else
        if current_group.isolate
          "#{@page_title} - #{current_group.name} #{current_group.legend}"
        else
          "#{@page_title} - #{current_group.name} - #{AppConfig.application_name} -  #{current_group.legend}"
        end
      end
    else
      if current_group.name == AppConfig.application_name
        "#{AppConfig.application_name} - #{t("layouts.application.title")}"
      else
        if current_group.isolate
          "#{current_group.name} - #{current_group.legend}"
        else
          "#{current_group.name} - #{current_group.legend} - #{AppConfig.application_name}"
        end
      end
    end
  end
  helper_method :page_title

  def feed_urls
    @feed_urls ||= Set.new
  end
  helper_method :feed_urls

  def add_feeds_url(url, title="atom")
    feed_urls << [title, url]
  end

  def admin_required
    unless current_user.admin?
      access_denied
    end
  end

  def moderator_required
    unless current_user.mod_of?(current_group)
      access_denied
    end
  end

  def is_bot?
    request.user_agent =~ /\b(Baidu|Gigabot|Googlebot|libwww-perl|lwp-trivial|msnbot|SiteUptime|Slurp|WordPress|ZIBB|ZyBorg|Java|Yandex|Linguee|LWP::Simple|Exabot|ia_archiver|Purebot|Twiceler)\b/i
  end
end
