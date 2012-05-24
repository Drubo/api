# app.rb
require 'sinatra' 
require 'net/http'
require 'net/https'
require 'json'
require './github'

set :token,  ENV['TOKEN']
helpers do
  def payload
    @payload = JSON.parse(params[:payload])
  end

  def repo
    @repo = "#{payload["repository"]["name"]}"
  end

  def gituser
    @gituser = "tareq@webkutir.net"
  end

  def gitemail
    @gitemail = "#{payload["repository"]["owner"]["email"]}"
  end
  
  def pusher
    @pusher = "#{payload["pusher"]["email"]}"
  end

  def github
    @github = GitHub.new(repo, gituser, settings.token)
  end
  
  def authorized?
    settings.token == params[:token]
  end
  
  def ref
    @ref = payload["ref"]
  end
  
  def respond_to_commits
    payload["commits"].reverse.each do |commit|
      yield commit
    end
    "OK"
  end
end

get '/' do
  'API Initialized...'
end

post '/action' do
  respond_to_commits do |commit|
    GitHub.closed_issues(commit["message"]) do |issue|
      github.noreopen issue
    end
  end
end