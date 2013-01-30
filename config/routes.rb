RedmineApp::Application.routes.draw do
  match 'bulk_time_entries/:action.:format', :controller => 'bulk_time_entries'

  get 'bulk_time_entries' => 'bulk_time_entries#index'
  get 'bulk_time_entries/load_assigned_issues.js' => 'bulk_time_entries#load_assigned_issues'
  post 'bulk_time_entries/save' => 'bulk_time_entries#save'
  get 'bulk_time_entries/add_entry' => 'bulk_time_entries#add_entry'
  get 'bulk_time_entries/time_entries_today' => 'bulk_time_entries#time_entries_today'
  post 'bulk_time_entries/time_entries_today' => 'bulk_time_entries#time_entries_today'
end

=begin
ActionController::Routing::Routes.draw do |map|
  map.connect 'bulk_time_entries/:action.:format', :controller => 'bulk_time_entries'
end
=end
