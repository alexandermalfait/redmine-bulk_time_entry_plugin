class BulkTimeEntriesController < ApplicationController
  unloadable
  layout 'base'
  before_filter :load_activities
  before_filter :load_allowed_projects

  helper :custom_fields

  
  def index
    @time_entries = [TimeEntry.new(:spent_on => Date.today.to_s)]

    if @projects.empty?
      render :action => 'no_projects'
    end
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

    render(:update) do |page|
      page.replace_html params[:entry_id]+'_issues', :partial => 'issues_selector', :locals => { :issues => @issues, :rnd => params[:entry_id].split('_')[1]  }
    end
  end
  
  
  def save
    if request.post? 
      @time_entries = params[:time_entries]

      render :update do |page|
        @time_entries.each_pair do |html_id, entry|
          next unless BulkTimeEntriesController.allowed_project?(entry[:project_id])
          @time_entry = TimeEntry.new(entry)
          @time_entry.hours = nil if @time_entry.hours.blank? or @time_entry.hours <= 0
          @time_entry.project_id = entry[:project_id] # project_id is protected from mass assignment
          @time_entry.user = User.current
          unless @time_entry.save
            page.replace "entry_#{html_id}", :partial => 'time_entry', :object => @time_entry
          else
            page.replace_html "entry_#{html_id}", "
              <div class='flash notice'>
                #{Time.now.strftime('%H:%M')}:
                #{l(:text_time_added_to_project, :hours => @time_entry.hours, :project => @time_entry.project.name)}
                #{" (#{@time_entry.comments})" unless @time_entry.comments.blank?}.
                <a href=\"javascript:void(null)\" onclick=\"$(this).up('div.box').remove()\"><img src=\"/images/close.png\" /></a>
              </div>
            "
          end
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
    spent_on ||= Date.today
    
    @time_entry = TimeEntry.new(:spent_on => spent_on.to_s)
    respond_to do |format|
      format.js do
        render :update do |page| 
          page.insert_html :bottom, 'entries', :partial => 'time_entry', :object => @time_entry
        end
      end
    end
  end
  
  private

  def load_activities
    @activities = BulkTimeEntryCompatibility::Enumeration::activities
  end
  
  def load_allowed_projects
    @projects = User.current.projects.find(:all,
      Project.allowed_to_condition(User.current, :log_time))
  end

  def self.allowed_project?(project_id)
    return User.current.projects.find_by_id(project_id, Project.allowed_to_condition(User.current, :log_time))
  end
end
