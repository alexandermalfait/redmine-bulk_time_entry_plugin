module BulkTimeEntriesHelper
  # Cheap knock off of the tabular form builder's labeling
  def label_for_field(field, rnd_id, options = { })
    label_text = l(options[:label]) if options[:label]
    label_text ||= l(("field_"+field.to_s.gsub(/\_id$/, "")).to_sym)
    #label_text += "<span class=\"required\">*</span>".html_safe if options.delete(:required)

    label = content_tag("label", label_text,
      :class => (@object && @object.errors[field].present? ? "error" : nil),
      :for => (@object_name.to_s + "_" + rnd_id.to_s + "_" + field.to_s)).html_safe

    label.html_safe
  end
  
  def grouped_options_for_issues(issues)
    closed_issues, open_issues = *issues.partition {|issue| issue.closed?}

    html = '<option></option>'
    unless open_issues.empty?
      html << labeled_option_group_from_collection_for_select(:label_open_issues, open_issues)
    end

    unless closed_issues.empty?
      html << labeled_option_group_from_collection_for_select(:label_closed_issues, closed_issues)
    end
    html
  end

  def labeled_option_group_from_collection_for_select(label, collection)
    html = "<optgroup label='#{l(label)}'>"
    html << options_from_collection_for_select(collection, :id, :to_s)
    html << "</optgroup>"
    html
  end

  def get_issues(project_id)
    project = BulkTimeEntriesController.allowed_project?(project_id)
    if project
      project.issues.all(:order => 'id ASC')
    else
      []
    end
  end
end
