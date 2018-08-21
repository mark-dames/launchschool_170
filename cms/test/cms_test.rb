ENV["RACK_ENV"] = "test"

require "minitest/autorun"
require "rack/test"
require "fileutils"

require_relative "../cms"

class CMSTest < Minitest::Test
  include Rack::Test::Methods
  
  def app
    Sinatra::Application
  end
  
  def setup
    FileUtils.mkdir_p(data_path)
  end
  
  def teardown
    FileUtils.rm_rf(data_path)
  end
  
  def session
    last_request.env["rack.session"]
  end
  
  def admin_session
    {"rack.session" => { username: "admin"} }
  end
  
  def tester_session
    {"rack.session" => { username: "tester"} }
  end
  
  def john_session
    {"rack.session" => { username: "jan"} }
  end
  
  def create_document(name, content = "")
    File.open(File.join(data_path, name), "w") do |file|
      file.write(content)
    end
  end
  
  def test_index
    create_document "about.md"
    create_document "changes.txt"
    
    get "/"
    
    assert_equal 200, last_response.status
    assert_equal "text/html;charset=utf-8", last_response["Content-Type"]
    assert_includes(last_response.body, "about.md")
    assert_includes(last_response.body, "changes.txt")
    assert_includes(last_response.body, "New Document")
  end
  
  def test_viewing_text_document
    create_document "history.txt", "1993 - Yukihiro Matsumoto dreams up Ruby.\n1995 - Ruby 0.95 released."
    
    get "/history.txt"
    
    assert_equal 200, last_response.status
    assert_equal "text/plain", last_response["Content-Type"]
    assert_includes(last_response.body, "1993 - Yukihiro Matsumoto dreams up Ruby.")
    assert_includes(last_response.body, "1995 - Ruby 0.95 released.")
  end
  
  def test_non_existing_documents
    get "/cities.txt"
    assert_equal 302, last_response.status
    
    assert_equal "cities.txt does not exist.", session[:message]
  end
  
  def test_markdown_files
    create_document "about.md", "#About Ruby...\nA dynamic, open source programming language with a focus on simplicity and productivity."
    
    get "/about.md"
    
    assert_equal 200, last_response.status
    assert_equal "text/html;charset=utf-8", last_response["Content-Type"]
    assert_includes(last_response.body, "<h1>About Ruby...</h1>")
  end
  
  def test_edit_document_when_signed_in
    create_document("changes.txt")
    
    get "/changes.txt/edit", {} , admin_session
    
    assert_equal 200, last_response.status
    assert_equal "text/html;charset=utf-8", last_response["Content-Type"]
    assert_includes(last_response.body, "<textarea")
  end
  
  def test_edit_document_when_signed_out
    create_document("changes.txt")
    get "changes.txt/edit"
    
    assert_equal 302, last_response.status
    assert_equal "You must be signed in to do that.", session[:message]
  end
    
  def test_update_document_when_signed_in
    post "/changes.txt", {new_content: "This is very new content."}, admin_session
    assert_equal 302, last_response.status
    
    assert_equal "changes.txt has been updated.", session[:message]
    
    get "/changes.txt"
    assert_equal 200, last_response.status
    assert_includes(last_response.body, "This is very new content.")
  end
  
  def test_update_document_when_signed_out
    post "/changes.txt", {new_content: "New Content."}
    assert_equal 302, last_response.status
    assert_equal "You must be signed in to do that.", session[:message]
  end
  
  def test_new_document_form_when_signed_in
    get "/new", {}, admin_session
    
    assert_equal 200, last_response.status
    assert_includes(last_response.body, "Add a new document:")
    assert_includes(last_response.body, "<button type=\"submit\">Create</button>")
  end
  
  def test_new_document_form_when_signed_out
    get "/new"
    
    assert_equal 302, last_response.status
    assert_equal "You must be signed in to do that.", session[:message]
  end
  
  def test_create_document_when_name_is_valid
    post "/create", {filename: "test.txt"}, admin_session
    assert_equal 302, last_response.status
    
    assert_equal "test.txt was created.", session[:message]

    get "/test.txt"
    assert_equal 200, last_response.status
  end
  
  def test_re_display_form_when_filename_is_invalid
    post "/create", {filename: ""}, admin_session
    assert_equal 422, last_response.status
    assert_includes(last_response.body, "Add a new document:")
    assert_includes(last_response.body, "<button type=\"submit\">Create</button>")
  end
  
  def test_delete_document_when_signed_in
    create_document "history.txt", "1993 - Yukihiro Matsumoto dreams up Ruby.\n1995 - Ruby 0.95 released."
    
    post "/history.txt/delete", {}, admin_session
    assert_equal 302, last_response.status
    assert_equal "history.txt was deleted.", session[:message] 

    refute_includes(last_response.body, "history.txt")
  end
  
  def test_delete_document_when_signed_out
    create_document "history.txt", "1993 - Yukihiro Matsumoto dreams up Ruby.\n1995 - Ruby 0.95 released."
    
     post "/history.txt/delete"
     assert_equal 302, last_response.status
     assert_equal "You must be signed in to do that.", session[:message]
  end
  
  def test_signup_form
    get "/signup"
    assert_equal 200, last_response.status
    assert_includes(last_response.body, "<input name=\"username\"")
  end
  
  def test_signup_with_valid_credentials
    post "/signup", {username: "jan", password: "12345"}
    assert_equal 302, last_response.status
    assert_equal "You have been signed up.", session[:message]
    
    get last_response["Location"]
    assert_equal 200, last_response.status
    assert_includes(last_response.body, "Signed in as jan")
    
    post "/delete_account"
  end
  
  def test_signup_with_invalid_credentials
    post "/signup", {username: "admin", password: "12345"}
    
    assert_equal 442, last_response.status
    assert_includes(last_response.body, "admin already exists. Please choose a different username.")
    assert_includes(last_response.body, "<input name=\"username\"")
  end
  
  def test_signin_form
    get "/users/signin"
    
    assert_equal 200, last_response.status
    assert_includes(last_response.body, "<input")
    assert_includes(last_response.body, "<button type=\"submit\"")
  end
  
  def test_signin_when_credentials_are_valid
    post "signin", { username: "admin", password: "secret"}, admin_session
    assert_equal 302, last_response.status
    
    assert_equal "Welcome!", session[:message]
    assert_equal "admin", session[:username]
    
    get "/"
    assert_equal 200, last_response.status
    assert_includes(last_response.body, "Signed in as admin.")
    assert_includes(last_response.body, "<button type=\"submit\">Sign Out</button>")
  end
  
  def test_when_credentials_are_invalid
    post "signin", username: "admin", password: "xxxxxxxx"
    assert_equal 442, last_response.status
    assert_nil(session[:username])
    assert_includes(last_response.body, "Invalid Credentials")
    assert_includes(last_response.body, "admin")
  end
  
  def test_when_user_signout
    get "/",{}, admin_session
    assert_includes(last_response.body, "Signed in as admin.")
    
    post "/signout"
    assert_equal "You have been signed out.", session[:message]
    assert_nil(session[:username])
    
    get last_response["Location"]
  
    assert_includes(last_response.body, "Sign In")
  end
  
  def test_restricted_access_for_user_signed_out
    get "/", admin_session
  end
  
  def test_user_account_page
    get "/account", {}, tester_session
    assert_equal 200, last_response.status
    assert_includes(last_response.body, "New Password")
    assert_includes(last_response.body, "<input type=\"password\"")
    assert_includes(last_response.body, "Delete your account")
  end
  
  def test_delete_account
    post "/signup", {username: "john", password: "12345"}
    assert_equal 302, last_response.status
    assert_equal "You have been signed up.", session[:message]
    
    post "/delete_account", john_session
    assert_equal 302, last_response.status
    assert_equal "Your account has been deleted.", session[:message]
    
    get last_response["Location"]
    assert_equal 200, last_response.status
    assert_includes(last_response.body, "Sign Up")
    
    post "signin", username: "john", password: "12345"
    assert_equal 442, last_response.status
    assert_nil(session[:username])
    assert_includes(last_response.body, "Invalid Credentials")
  end
  
  def test_change_password
    post "/signup", {username: "gerrit", password: "12345"}
    assert_equal 302, last_response.status
    assert_equal "You have been signed up.", session[:message]
    
    post "/change_password", {new_password: "54321"}
    assert_equal 302, last_response.status
    assert_equal "The password is changed.", session[:message]
    
    post "/signout"
    assert_equal "You have been signed out.", session[:message]
    
    post "signin", {username: "gerrit", password: "54321"}
    assert_equal 302, last_response.status
    assert_equal "Welcome!", session[:message]
    
    post "/delete_account"
  end
end