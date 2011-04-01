class ReTaskController < RedmineReController
  unloadable
  menu_item :re

  def delete_subtask
    id = params[:id] #id of the subtask if new subtask then it's: new_pos => new_2
    @position = params[:pos] # new_pos if new subtask otherwise pos
    is_saved_subtask = !@position.to_s.starts_with?("new")

    # delete existent subtask
    if is_saved_subtask
      @subtask = ReSubtask.find(id)

      @subtask.re_artifact_properties.destroy
      @subtask.destroy
    end

    # remove tr of the subtask

     respond_to do |format|
       format.js
     end


  end

  def index
    @tasks = ReTask.find(:all,
                         :joins => :re_artifact_properties,
                         :conditions => { :re_artifact_properties => { :project_id => params[:project_id]} }
    )
    render :layout => false if params[:layout] == 'false'
  end


  def new
    redirect_to :action => 'edit', :project_id => params[:project_id]
  end

  def edit
    @re_task = ReTask.find_by_id(params[:id], :include => :re_artifact_properties) || ReTask.new(:re_artifact_properties => ReArtifactProperties.new(:project_id => @project.id))
    @subtasks = []
    @re_task.children.each {|c| @subtasks << c.artifact if c.artifact_type == "ReSubtask"}
    @project ||= @re_task.project
    @html_tree = create_tree

    if request.post?
      # check validation of task and subtask attributes

      valid_task = true
      valid_subtask_attributes = true
      subtask_attributes = params[:re_task].delete(:subtask_attributes)

      ## Task validation
      @re_task.attributes = params[:re_task]
      valid_task = @re_task.valid?

      ## subtask_attributes validation
      valid_subtask_attributes = @re_task.subtasks_valid?(subtask_attributes)

      # Saving everything
      if valid_task && valid_subtask_attributes
        if @re_task.save
          # Save all subtasks
          @re_task.subtask_attributes = subtask_attributes

          flash[:notice] = t(:re_task_and_subtasks_saved)
          redirect_to :action => 'edit', :id => @re_task.id and return
        end
      else
        # Get all Subtasks sorted by their position
        @subtasks = @re_task.get_subtasks_sorted_by_position(subtask_attributes)

        # Add error to task
        # TODO: Distinguish type of error and translate
        @re_task.errors.add_to_base(t(:re_subtasks_not_valid)) unless valid_subtask_attributes
      end
    end
  end


  ##
  # deletes and updates the flash with either success, id not found error or deletion error
  def delete
    @re_task = ReTask.find_by_id(params[:id], :include => :re_artifact_properties)
    @project ||= @re_task.project
    
    if !@re_task
      flash[:error] = t(:re_task_not_found, :id => params[:id])
    else
      name = @re_task.re_artifact_properties.name
      subtasks = []
      @re_task.children.each {|c| subtasks << c.artifact if c.artifact_type == "ReSubtask"}

      if ReTask.destroy(@re_task.id)
        # destroy subtasks
        subtasks.each { |subtask| subtask.destroy } #todo: clean up relations ?for example par/child relations between orher artifact types?
        flash[:notice] = t(:re_task_deleted, :name => name)
      else
        flash[:error] = t(:re_task_not_deleted, :name => name)
      end
    end
    redirect_to :controller => 'requirements', :action => 'index', :project_id => @project.id
  end

  ##
  # unused right now
  def show
    @re_task = ReTask.find_by_id(params[:id])
  end

  ##
  # shows all versions
  def show_versions #todo das view funktioniert
    @task = ReTask.find(params[:id] ) # :include => :re_artifact_properties)
  end

  ##
  # reverts to an older version
  def change_version
    targetVersion = params[:version]
    @task = ReTask.find(params[:id])

    if(@task.revert_to!(targetVersion))
      flash[:notice] = 'Task version changed sucessfully'
    end

    redirect_to :action => 'index', :project_id => @project.id
  end

end
