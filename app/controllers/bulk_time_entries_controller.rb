# -*- coding: utf-8 -*-
class BulkTimeEntriesController < ApplicationController
  unloadable
  layout 'base'
  before_filter :load_activities
  before_filter :load_allowed_projects
  before_filter :check_for_no_projects

  helper :custom_fields
  include BulkTimeEntriesHelper

  protect_from_forgery :only => [:index, :save]
  
  def index
    @time_entries = [TimeEntry.new(:spent_on => today_with_time_zone.to_s)]

    load_allowed_projects
  end

  def get_issues(project_id, assigned_to_id = nil, only_open = false)
    # would prefer to build the sql through named scopes :|
    conditions_sql = []
    conditions_params = []

    conditions_sql << "project_id = ?"
    conditions_params << project_id

    if assigned_to_id
      conditions_sql << "assigned_to_id = ?"
      conditions_params << assigned_to_id
    end

    if only_open
      conditions_sql << "issue_statuses.is_closed = ?"
      conditions_params << false
    end

    @issues = Issue.find(:all, :conditions => [ conditions_sql.join(' AND ') ] + conditions_params, :include => :status)
  end

  def load_assigned_issues
    get_issues params[:project_id], params[:assigned_to_id], params[:only_open]

    render :partial => 'issues_selector', :locals => { :issues => @issues, :rnd => params[:entry_id].split('_')[1]  }
  end
  
  
  def save
    if request.post? 
      @time_entries = params[:time_entries]

      @time_entries.each_pair do |html_id, entry|
        next unless BulkTimeEntriesController.allowed_project?(entry[:project_id])
        @time_entry = TimeEntry.new(entry)
        @time_entry.hours = nil if @time_entry.hours.blank? or @time_entry.hours <= 0
        @time_entry.project_id = entry[:project_id] # project_id is protected from mass assignment
        @time_entry.user = User.current

        unless @time_entry.save
          render :partial => 'time_entry', :object => @time_entry
        else
          render :text => "
            <div class='flash notice'>
              #{Time.now.strftime('%H:%M')}:
              #{l(:text_time_added_to_project, :hours => @time_entry.hours, :project => @time_entry.project.name)}
              #{" (#{@time_entry.comments})" unless @time_entry.comments.blank?}.
              <a href=\"javascript:void(null)\" onclick=\"$(this).closest('form').remove()\"><img src=\"/images/close.png\" /></a>
            </div>
          "
        end
      end
    end
  end
    
  def add_entry
    begin
      spent_on = Date.parse(params[:date])
    rescue ArgumentError, TypeError
      # Fall through
    end
    spent_on ||= today_with_time_zone

    load_allowed_projects

    @time_entry = TimeEntry.new(:spent_on => spent_on.to_s)

    if params[:issue_id]
      @selected_issue = Issue.find(params[:issue_id])

      @time_entry.project = @selected_issue.project
      @time_entry.issue = @selected_issue

      @selected_project = @selected_issue.project

      @issues = [ @selected_issue ]
    end

    render :partial => "time_entry", :locals => { :time_entry => @time_entry }
  end

  def time_entries_today
    @entries = TimeEntry.all(
      :conditions => ["#{TimeEntry.table_name}.user_id = ? AND #{TimeEntry.table_name}.spent_on = ?", find_current_user.id, Date.today],
      :include => [:activity, :project, {:issue => [:tracker, :status]}],
      :order => "#{TimeEntry.table_name}.created_on DESC"
    )

    @user = find_current_user

    render :layout => false
  end


  private

  def load_activities
    @activities = TimeEntryActivity.all
  end
  
  def load_allowed_projects
    @projects = User.current.projects.find(:all, Project.allowed_to_condition(User.current, :log_time))
  end

  def check_for_no_projects
    if @projects.empty?
      render :action => 'no_projects'
      return false
    end
  end


  # Returns the today's date using the User's time_zone
  #
  # @return [Date] today
  def today_with_time_zone
    time_proxy = Time.zone = User.current.time_zone
    time_proxy ||= Time # In case the user has no time_zone
    today = time_proxy.now.to_date
  end

  def self.allowed_project?(project_id)
    return User.current.projects.find_by_id(project_id, :conditions => Project.allowed_to_condition(User.current, :log_time))
  end
end
