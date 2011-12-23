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
    @gituser = "#{payload["repository"]["owner"]["name"]}"
  end

  def gitemail
    @gitemail = "#{payload["repository"]["owner"]["email"]}"
  end

  def github
    @github = GitHub.new(repo, gituser, settings.token)
  end
  
  def authorized?
    settings.token == params[:token]
  end
  
  def respond_to_commits
    return "UNKNOWN APP" unless authorized?
    payload["commits"].reverse.each do |commit|
      yield commit
    end
    "OK"
  end
end

get '/' do
  'Api Initialized...'
end

post '/action/:token' do
  respond_to_commits do |commit|
    GitHub.closed_issues(commit["message"]) do |issue|
      if commit["author"]["email"]==gitemail
        github.noreopen issue, commit["author"]["name"]
      else
        github.reopen issue, commit["id"], commit["author"]["name"]
      end 
    end
  end
end