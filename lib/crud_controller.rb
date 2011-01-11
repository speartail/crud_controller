class CrudController < ApplicationController

  around_filter :catch_record_not_found
  before_filter :get_shared_data
  before_filter :update_user, :only => [ :edit, :new ]
  before_filter :update_user_and_save, :only => [ :create, :update ]

  def initialize
    @me = self.class.to_s.sub(/Controller/, '')
    @var_singular = to_singular_var(@me)
    @var_plural = to_plural_var(@me)
    @class_singular = to_class_name(@me)
  end

  def index(limit = nil)
    eval("order = #{@class_singular}.column_names.include?('sort_order') ? 'sort_order ASC' : #{@class_singular}.column_names.include?('code') ? 'code ASC' : 'created_at DESC'")
    eval("@#{@var_plural} = #{@class_singular}.find(:all, :order => order #{limit.to_i > 0 ? ', :limit => ' + limit.to_s : ''} )")
    respond_to do |format|
      format.html
      format.csv { eval("send_data_as_file(#{@class_singular}.to_csv(@current_user.field_separator))") }
    end
  end

  def edit
    respond_to do |format|
      format.html { request.xhr? ? eval("render :partial => 'edit_item', :locals => { :#{@var_singular} => @#{@var_singular} }") : render(:action => 'edit') }
    end
  end

  def show
    respond_to do |format|
      format.html { request.xhr? ? eval("render :partial => 'show_item', :locals => { :#{@var_singular} => @#{@var_singular} }") : render(:action => 'show') }
    end
  end

  def new
    respond_to do |format|
      format.html { request.xhr? ? eval("render :partial => 'new_item', :locals => { :#{@var_singular} => @#{@var_singular} }") : render(:action => 'new') }
    end
  end

  def create(redirect_to_path = nil)
    eval("@#{@var_singular} = create_new_item_from_params")
    respond_to do |format|
      if eval("@#{@var_singular}.save")
        flash[:notice] = "#{@class_singular} was successfully created."
        format.html { request.xhr? ? eval("render :partial => 'show_item', :locals => { :#{@var_singular} => @#{@var_singular} }") : redirect_to(redirect_to_path.nil? ? eval("#{@var_plural}_path") : redirect_to_path) }
      else
        format.html { request.xhr? ? render(:text => "Error creating #{@var_singular}") : render(:action => "new") }
      end
    end
  end

  def update(redirect_to_path = nil)
    unless eval("@#{@var_singular}.id.nil?")
      respond_to do |format|
        if eval("@#{@var_singular}.update_attributes(params[:#{@var_singular}])")
          flash[:notice] = "#{@class_singular} was successfully updated."
          format.html { request.xhr? ? eval("render :partial => 'show_item', :locals => { :#{@var_singular} => @#{@var_singular} }") : redirect_to(redirect_to_path.nil? ? eval("#{@var_plural}_path") : redirect_to_path) }
        else
          format.html { request.xhr? ? render(:text => "Error updating #{@var_singular}") : render(:action => "edit") }
        end
      end
    else
      redirect_to(eval("#{@var_plural}_path"))
    end
  end
  
  def destroy(redirect_to_path = nil)
    eval("@#{@var_singular}.destroy")
    respond_to do |format|
      format.html { request.xhr? ? render(:nothing => true) : redirect_to(redirect_to_path.nil? ? eval("#{@var_plural}_path") : redirect_to_path) }
    end
  end

  # Ajax

  [ 'name', 'code' ].each do |field|
    define_method("def auto_complete_for_#{@var_singular}_#{field}") do
      eval("@#{@var_singular} = #{@class_name}.find_for_auto_complete(params[:#{@var_singular}][:#{field}])")
      eval(render(:partial => "/#{@var_plural}/auto_complete"))
    end
  end

  # Utility functions

  def to_singular_var(name)
    return name.singularize.underscore
  end

  def to_plural_var(name)
    return name.pluralize.underscore
  end

  def to_class_name(name)
    return name.singularize.camelcase
  end

  # Converts a regular array of ActiveRecords into \<option> tags for use with #select_tag
  #
  # <b>Options</b>:
  # * array_of_records  - the array to (non-destructively) convert
  # * add_all_option    - add an option for 'All' to the set
  # * add_blank_option    - add an option for 'All' to the set
  # * add_manual_option    - add an option for 'All' to the set
  def array_to_options(array_of_records, options = {})
    result = ''
    result_array = add_all_option(array_of_records, options[:add_all_option])
    result_array = add_blank_option(result_array, options[:add_blank_option])
    result_array = add_manual_option(result_array, options[:add_manual_option])
    result_array.each { |r| result = "#{result}<option #{((options[:default_record] && options[:default_record].length > 0) && (options[:default_record] == r[0])) ? "selected='selected' " : '' }value='#{r[1]}'>#{r[0]}</option>"}
    return result
  end

  def add_all_option(array_of_records, add_all_option = true)
    result_array = array_of_records.clone
    result_array.insert(0, [ 'All', 0 ]) if add_all_option
    return result_array
  end

  def add_manual_option(array_of_records, add_manual_option = true)
    result_array = array_of_records.clone
    result_array << [ '>> Manual <<', -1 ] if add_manual_option
    return result_array
  end

  def add_blank_option(array_of_records, add_blank_option = true)
    result_array = array_of_records.clone
    result_array.insert(0, [ '', -1 ]) if add_blank_option
    return result_array
  end

  protected
  def update_user
    # update_with_user_defaults is safe to call on all ActiveRecords
    eval("@#{@var_singular}.update_with_user_defaults(@current_user, false)")
  end

  def update_user_and_save
    eval("@#{@var_singular}.update_with_user_defaults(@current_user, true)")
  end

  private
  def get_shared_data
    params.each_pair do |p, value|
      if %r[_id$].match(p)
        base = p.sub(/_id$/, '')
        eval("@#{to_singular_var(base)} = #{to_class_name(base)}.find_with_assoc(#{value})") 
      end
    end
    eval("@#{@var_singular} = params[:id].to_i > 0 ? #{@class_singular}.find_with_assoc(params[:id]) : create_new_item")
  end

  def create_new_item
    return eval("#{@class_singular}.new")
  end

  def create_new_item_from_params
    return eval("#{@class_singular}.new(params[:#{@var_singular}])")
  end

  def catch_record_not_found
    def redirect_or_error(e)
      case RAILS_ENV
      when 'development'
        raise(e)
      when 'production', 'test'
        redirect_to '/'
      end
    end
    begin
      yield
    rescue ActiveRecord::RecordNotFound => e
      msg = "Could not find the #{@class_singular.downcase} with id: #{params[:id]}"
      logger.warn msg
      logger.warn e.message
      flash[:error] = msg
      redirect_or_error(e)
    rescue Exception => e
      flash[:error] = "We're sorry, but an unhandled error occured. Please contact support: #{e.message}"
      logger.fatal "Unhandled Exception in CrudController.catch_record_not_found: " + e.message
      redirect_or_error(e)
    end
  end
end
