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
  
  def accepted
    @accepted = "false"
  end

  def waiting
    @waiting = "false"
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
    call env.merge("PATH_INFO" => '/reopen/'+commit["author"]["name"]+'/'+commit["message"]+"/"+commit["id"]) unless commit["author"]["email"]==gitemail
    if commit["author"]["email"]==gitemail
      call env.merge("PATH_INFO" => '/noreopen/'+commit["author"]["name"]+'/'+commit["message"])
    end 
  end
end

post '/reopen/:commiter/:commit_message/:commit_id' do
  GitHub.closed_issues(params[:commit_message]) do |issue|
    accepted = "false"
    waiting = "false"
    github.view_issue_label issue do |label|
      if label=="Accepted"
        accepted = "true"
      end
      if label=="Waiting For Review"
        waiting = "true"
      end
    end
    return "Issue Accepted" if accepted=="true"
    if waiting=="true"
      github.reopen_issue issue
      return "Issue Already Waiting for Review"
    end
    github.reopen_issue issue
    call env.merge("PATH_INFO" => '/comment/'+issue+'/'+params[:commit_id])
    github.remove_issue_label issue, "New Issue"
    github.add_issue_label issue, params[:commiter]
    github.add_issue_label issue, "Waiting For Review"
  end
end

post '/noreopen/:commiter/:commit_message' do
  GitHub.closed_issues(params[:commit_message]) do |issue|
    github.remove_issue_label issue, "New Issue"
    github.add_issue_label issue, params[:commiter]
    github.add_issue_label issue, "Accepted"
  end
end

post '/comment/:issue/:commit_id' do
  comment = <<EOM
Issue referenced by #{params[:commit_id]} is reopening automatically for Review
EOM
  github.comment_issue params[:issue], comment
end