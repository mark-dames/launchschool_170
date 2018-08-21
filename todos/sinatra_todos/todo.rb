require "sinatra"
require "sinatra/reloader" if development?
require "sinatra/content_for"
require "tilt/erubis"

configure do
  enable :sessions
  set :session_secret, 'secret'
  set :erb, :escape_html => true
end

helpers do
  def all_todos_completed?(list)
    list[:todos].size > 0 && list[:todos].all? { |todo| todo_completed?(todo) } 
  end
  
  def todo_completed?(todo)
    todo[:completed]
  end
  
  def check_todos(list)
    todos = list[:todos].size
    completed_todos = list[:todos].count { |todo| !todo_completed?(todo) }
    "#{completed_todos} / #{todos}"
  end
  
  def sort_todos(todos)
    completed, not_completed = todos.partition { |todo| todo_completed?(todo) }
    (not_completed + completed).each { |todo| yield todo }
  end
  
  def sort_lists(lists)
    completed, not_completed = lists.partition { |list| all_todos_completed?(list) }
    (not_completed + completed).each { |list| yield list }
  end
end

before do
  session[:lists] ||= []
end

def load_list(id)
  list = session[:lists].find {|list| list[:id] == id }
  return list if list
  
  session[:error] = "The specified list was not found."
  redirect "/lists"
end

def next_element_id(elements)
  max = elements.map {|element| element[:id] }.max || 0
  max + 1
end

get "/" do
  redirect "/lists"
end

# View all the lists.
get "/lists" do
  @lists = session[:lists]
  erb :lists, layout: :layout
end

# render the new list form. 
get "/lists/new" do
  erb :new_list, layout: :layout
end

# Return an error message if the list name is invalid. Return nil if list name is valid.
def error_for_list_name(name)
  if !(1..100).cover? name.size
    "List name must be between 1 and 100 characters."
  elsif session[:lists].any? {|list| list[:name] == name}
    "List name must be unique."
  end
end

# Return an error message if the todo name is invalid. Return nil if todo name is valid.
def error_for_todo(name)
  if !(1..100).cover? name.size
    "Todo name must be between 1 and 100 characters."
  end
end

# Create a new list.
post "/lists" do
  list_name = params[:list_name].strip
  
  error = error_for_list_name(list_name)
  if error
    session[:error] = error
    erb :new_list, layout: :layout
  else
    id = next_element_id(session[:lists])
    session[:lists] << {id: id, name: list_name, todos: []}
    session[:success] = "The list has been created."
    redirect "/lists"
  end
end

# View a single list
get "/lists/:id" do
  id = params[:id].to_i
  @list = load_list(id)
  @list_name = @list[:name]
  @list_id = @list[:id]
  @todos = @list[:todos]
  erb :list, layout: :layout
end

# edid an existing todo list
get "/lists/:id/edit" do
  @id = params[:id].to_i
  @list = load_list(@id)
  
  erb :edit_list, layout: :layout
end

# Update an existing todo list.
post "/lists/:id" do
  @id = params[:id].to_i
  @list = load_list(@id)
  list_name = params[:list_name].strip
  
  error = error_for_list_name(list_name)
  if error
    session[:error] = error
    erb :edit_list, layout: :layout
  else
    @list[:name] = list_name
    session[:success] = "The list has been updated."
    redirect "/lists/#{@id}"
  end
end

# Delete a todo list.
post "/lists/:id/destroy" do
  id = params[:id].to_i
  session[:lists].reject! { |list| list[:id] == id }
  session[:success] = "The list has been deleted."
  if env["HTTP_X_REQUESTED_WITH"] == "XMLHttpRequest"
    "/lists"
  else
    session[:success] = "The list has been deleted."
    redirect "/lists"
  end
end

# Add a new todo to the list.
post "/lists/:list_id/todos" do
  @list_id = params[:list_id].to_i
  @list = load_list(@list_id)
  text = params[:todo].strip
  
  error = error_for_todo(text)
  if error
    session[:error] = error
    erb :list, layout: :layout
  else
    
    id = next_element_id(@list[:todos])
    @list[:todos] << {id: id, name: text, completed: false}
    
    session[:success] = "The todo was added."
    redirect "/lists/#{@list_id}"
  end
end

# Delete a todo from a list.
post "/lists/:list_id/todos/:todo_id/delete" do
  @list_id = params[:list_id].to_i
  @list = load_list(@list_id)
  
  todo_id = params[:todo_id].to_i
  @list[:todos].reject! {|todo| todo[:id] == todo_id }
  #list[:todos].delete_at(todo_id)
  if env["HTTP_X_REQUESTED_WITH"] == "XMLHttpRequest"
    status 204
  else
    session[:success] = "The todo has been deleted."
    redirect "/lists/#{@list_id}"
  end
end

# Update status of a todo. 
post "/lists/:list_id/todos/:todo_id" do
  @list_id = params[:list_id].to_i
  @list = load_list(@list_id)
  
  todo_id = params[:todo_id].to_i
  is_completed = params[:completed] == "true"
  todo = @list[:todos].find { |todo| todo[:id] == todo_id }
  todo[:completed] = is_completed
  
  #@list[:todos][todo_id][:completed] = is_completed
  
  session[:success] = "The todo has been updated."
  redirect "/lists/#{@list_id}"
end

# Mark all todos as complete for a list. 
post "/lists/:id/complete_all" do
  @list_id = params[:id].to_i
  @list = load_list(@list_id)
  
  @list[:todos].each do |todo|
    todo[:completed] = true
  end
  
  session[:success] = "All todos have been completed."
  redirect "/lists/#{@list_id}"
end


  
