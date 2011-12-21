# app.rb
require 'sinatra' 
require 'net/http'
require 'net/https'
require 'json'
require './github'
require 'pp'

set :token,  ENV['TOKEN']
helpers do
  def payload
    @payload = JSON.parse(params[:payload])
  end

  def repo
    @repo = "Verified"
  end

  def gituser
    @gituser = "Drubo"
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
  issue_info = (github.view_issue 52)
  issue_info.each do |label|
    label["issues"]
  end
end

post '/action/:token' do
  respond_to_commits do |commit|
    call env.merge("PATH_INFO" => '/reopen/'+commit["author"]["name"]+'/'+params[:token]) unless commit["author"]["email"]==gitemail
    if commit["author"]["email"]==gitemail
      call env.merge("PATH_INFO" => '/noreopen/'+params[:token])
    end 
  end
end

post '/label/refer/:label/:token' do
  respond_to_commits do |commit|
    GitHub.nonclosing_issues(commit["message"]) do |issue|
      github.label_issue issue, params[:label]
    end
  end
end

post '/label/closed/:label/:token' do
  respond_to_commits do |commit|
    GitHub.closed_issues(commit["message"]) do |issue|
      github.label_issue issue, params[:label]
    end
  end
end

post '/label/remove/closed/:label/:token' do
  respond_to_commits do |commit|
    GitHub.closed_issues(commit["message"]) do |issue|
      github.remove_issue_label issue, params[:label]
    end
  end
end

post '/reopen/:commiter/:token' do
  respond_to_commits do |commit|
    GitHub.closed_issues(commit["message"]) do |issue|
      GitHub.view_issue(issue) do |label|
        if label=="Accepted"
          accepted = "true"
        end
      end
      return "Issue Accepted" if accepted=="true"
      github.reopen_issue issue
      call env.merge("PATH_INFO" => '/comment/'+params[:token])
      call env.merge("PATH_INFO" => '/label/remove/closed/New Issue/'+params[:token])
      call env.merge("PATH_INFO" => '/label/closed/'+params[:commiter]+'/'+params[:token])
      call env.merge("PATH_INFO" => '/label/closed/Waiting For Review/'+params[:token])
    end
  end
end

post '/noreopen/:token' do
  respond_to_commits do |commit|
    GitHub.closed_issues(commit["message"]) do |issue|
      call env.merge("PATH_INFO" => '/label/remove/closed/New Issue/'+params[:token])
      call env.merge("PATH_INFO" => '/label/closed/'+params[:commiter]+'/'+params[:token])
      call env.merge("PATH_INFO" => '/label/closed/Accepted/'+params[:token])
    end
  end
end

post '/comment/:token' do
  respond_to_commits do |commit|
    comment = <<EOM
Issue referenced by #{commit["id"]} is reopening automatically for Review
EOM
    GitHub.nonclosing_issues(commit["message"]) do |issue|
      github.comment_issue issue, comment
    end
  end
end