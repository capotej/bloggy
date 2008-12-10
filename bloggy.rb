require 'rubygems'
require 'sinatra'
require 'jdbc_adapter'
require 'sequel'
require 'json'
require 'logger'

DB = Sequel.connect('jdbc:sqlite:posts.db')

#create table unless already exists
unless DB.table_exists?("posts")
  
  DB.create_table :posts do
    primary_key :id
    column :title, :string
    column :body, :text
  end

end

#Post model and validations
class Post < Sequel::Model
  validates_presence_of :title
  validates_presence_of :body
    
  def self.respond(params)
    
    #edit or create
    if params[:id]
      post = self.find(params[:id])
    else
      post = self.new
    end

    data = JSON.parse(params[:data])
    
    post.title = data["title"] 
    post.body = data["body"]
    
    if post.save
      { :status => 'OK', :title => post.title }
    else
      { :status => 'FAIL' }
    end
        
  end

end

#JSONP support, any request can carry a &callback= and it will be fed back to you
def jsonp(params, response)
  if params[:callback]
    params[:callback] + "(#{response.to_json});"
  else
    response.to_json
  end
end

#Set all content_type's to json
before do
  content_type 'text/json'
end

#GET /index.html
get '/' do
  redirect '/index.html'
end

#GET /posts returns all posts as json
get '/posts' do
  jsonp(params, DB[:posts].all)
end

#GET /post/1 returns that post as json
get '/post/:id' do
  jsonp(params, Post.find(params[:id]).values)
end

#PUT /post/1 update that post with json
put '/post/:id' do
  jsonp(params, Post.respond(params))
end

#POST /post body with data field set to JSON: { "title": "test", "body": "body test" }
post '/post' do
  jsonp(params, Post.respond(params))
end

#DELETE /post/1 deletes post
delete '/post/:id' do
  post = Post.find(params[:id])
  if post.destroy
    jsonp(params,{ :status => 'OK', :title => post.title })
  end
end


