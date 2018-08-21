require "sinatra"
require "sinatra/reloader"
require "tilt/erubis"
require "redcarpet"
require "fileutils"
require 'yaml'
require 'bcrypt'

configure do
  enable :sessions
  set :session_secret, 'very top secret'
end

def data_path
  if ENV["RACK_ENV"] == "test"
    File.expand_path("../test/data", __FILE__)
  else
    File.expand_path("../data", __FILE__)
  end
end

def markdown_to_html(text)
  markdown = Redcarpet::Markdown.new(Redcarpet::Render::HTML)
  markdown.render(text)
end

def load_file(file_path)
  extname = File.extname(file_path)
  content = File.read(file_path)
  if extname == ".md"
    erb markdown_to_html(content)
  else
    headers["Content-Type"] = "text/plain"
    content
  end
end

def check_if_user_is_signed_in
  unless session[:username]
    session[:message] = "You must be signed in to do that."
    redirect "/"
  end
end

not_found do
  redirect "/"
end

get "/" do
  pattern = File.join(data_path, "*")
  @files = Dir.glob(pattern).map { |path| File.basename(path) }
  
  erb :index
end

get "/new" do
  check_if_user_is_signed_in
  erb :new
end

get "/signup" do
  erb :signup
end

get "/account" do
  check_if_user_is_signed_in
  
  erb :account
end

get "/:filename" do
  file_path = File.join(data_path, params[:filename]) 
  
  if File.file?(file_path)
    load_file(file_path)
  else
    session[:message] = "#{params[:filename]} does not exist."
    redirect "/"
  end
end

get "/:filename/edit" do
  check_if_user_is_signed_in
  file_path = File.join(data_path, params[:filename])
  
  @filename = params[:filename]
  @content = File.read(file_path)
  
  erb :edit
end

get "/users/signin" do
  
  erb :signin
end

def valid_name?(filename)
  filename.match(/^[a-z]+\.(md|txt)$/)
end

post "/create" do
  check_if_user_is_signed_in
  file_path = File.join(data_path, params[:filename])
  filename = params[:filename].strip
  if valid_name?(filename)
    FileUtils.touch file_path
  
    session[:message] = "#{filename} was created."
    redirect "/"
  else
    session[:message] = "A valid text or markdown filename is required.."
    status 422
    erb :new
  end
end

def credentials_path
  if ENV["RACK_ENV"] == "test"
    File.expand_path("../test/users.yml", __FILE__)
  else
    File.expand_path("../users.yml", __FILE__)
  end
end

def valid_credentials?(username, password)
  users = YAML.load_file(credentials_path)
  if users.key?(username) 
    bcrypt_password = BCrypt::Password.new(users[username][:password]) 
    bcrypt_password == password
  end
end

post "/signup" do
  username = params[:username]
  password = params[:password]
  users = YAML.load_file(credentials_path)
  if users.key?(username)
    status 442
    session[:message] = "#{username} already exists. Please choose a different username."
    erb :signup
  else
    hashed_password = BCrypt::Password.create(password)
    new_user = {username => {password: hashed_password}}.to_yaml.gsub('-', '')
    File.open(credentials_path, "a") {|file| file << new_user }
    session[:message] = "You have been signed up."
    session[:username] = username
    redirect "/"
  end
end

post "/signin" do
  username = params[:username]
  password = params[:password]
  if valid_credentials?(username, password)
    session[:message] = "Welcome!"
    session[:username] = username
    redirect "/"
  else
    session[:message] = "Invalid Credentials"
    status 442
    erb :signin
  end
end

post "/signout" do
  session.delete(:username)
  session[:message] = "You have been signed out."
  redirect "/"
end

post "/change_password" do
  new_password = params[:new_password]
  hashed_password = BCrypt::Password.create(new_password)
  users = YAML.load_file(credentials_path)
  users[session[:username]][:password] = hashed_password
  File.open(credentials_path, "w") {|f| YAML.dump(users, f) }
  
  session[:message] = "The password is changed."
  redirect "/"
end

post "/delete_account" do
  users = YAML.load_file(credentials_path)
  username = session[:username]
  users.delete(username)
  File.open(credentials_path, "w") {|f| YAML.dump(users, f) }
  session.delete(:username)
  
  session[:message] = "Your account has been deleted."
  redirect "/"
end

post "/:filename" do
  check_if_user_is_signed_in
  file_path = File.join(data_path, params[:filename])
  
  new_content = params[:new_content]
  File.write(file_path, new_content)
  
  session[:message] = "#{params[:filename]} has been updated."
  redirect "/"
end

post "/:filename/delete" do
  check_if_user_is_signed_in
  file_path = File.join(data_path, params[:filename])
  FileUtils.rm_r(file_path)
  
  session[:message] = "#{params[:filename]} was deleted."
  redirect "/"
end