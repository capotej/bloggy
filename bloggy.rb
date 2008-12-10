require 'rubygems'
require 'sinatra'
require 'jdbc_adapter'
require 'sequel'
require 'json'
require 'logger'

DB = Sequel.connect('jdbc:sqlite::posts.db:', :loggers => [Logger.new('db.log')] )

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
      { :status => 'OK', :title => post.title }.to_json
    else
      { :status => 'FAIL' }.to_json
    end
        
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
  DB[:posts].all.to_json
end

#GET /post/1 returns that post as json
get '/post/:id' do
  Post.find(params[:id]).values.to_json
end

#PUT /post/1 update that post with json
put '/post/:id' do
  Post.respond(params)
end

#POST /post body with data field set to JSON: { "title": "test", "body": "body test" }
post '/post' do
  Post.respond(params)
end

#DELETE /post/1 deletes post
delete '/post/:id' do
  post = Post.find(params[:id])
  if post.destroy
    { :status => 'OK', :title => post.title }.to_json
  end
end


