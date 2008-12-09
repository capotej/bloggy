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
end


#GET / Returns all posts as json
get '/' do

  content_type 'text/json'
  
  posts = Post.find :all
  posts.to_json

end

#POST body with data field set to url encoded JSON: { "title": "test", "body": "body test" }
post '/post' do

  content_type 'text/json'

  if params[:data]
   
    data = ActiveSupport::JSON.decode(params[:data])
       
    post = Post.new({:title => data["title"], :body => data["body"]})
    
    if post.save
      { :status => 'OK' }.to_json
    else
      throw :halt, [500, 'no worky']
    end
  
  else
    throw :halt, [500, 'data please']
  end
end

