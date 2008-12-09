require 'rubygems'
require 'sinatra'
gem 'activerecord-jdbc-adapter'
require 'jdbc_adapter'
require 'active_record'

ActiveRecord::Base.establish_connection(:adapter => "jdbcderby", :database => "db/posts")

begin
  ActiveRecord::Schema.define do
    create_table :posts do |t|
      t.string :title
      t.text :body
      t.timestamps
    end
  end
rescue ActiveRecord::StatementInvalid
end

class Post < ActiveRecord::Base
  validates_presence_of :title
  validates_presence_of :body
end

#Generic active record response function
def respond(obj)
  if obj.save
    { :status => 'OK', :title => obj.title }.to_json
  else
    { :status => 'FAIL' }.to_json
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
  Post.find(:all).to_json
end

#GET /post/1 returns that post as json
get '/post/:id' do
  Post.find(params[:id]).to_json
end

#PUT /post/1 update that post with json
put '/post/:id' do
  
  post = Post.find(params[:id])
  data = ActiveSupport::JSON.decode(params[:data])

  post.title = data["title"] 
  post.body = data["body"]

  respond(post)
  
end

#POST /post body with data field set to JSON: { "title": "test", "body": "body test" }
post '/post' do

  data = ActiveSupport::JSON.decode(params[:data])
  post = Post.new({:title => data["title"], :body => data["body"]})

  respond(post)

end

#DELETE /post/1 deletes post
delete '/post/:id' do
  post = Post.find(params[:id])
  if post.destroy
    { :status => 'OK', :title => post.title }.to_json
  end
end
