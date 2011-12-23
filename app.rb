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
  
  def found
    @found = "false"
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
  call env.merge("PATH_INFO" => '/reopen/60/1234/Tariqul Islam')
end

post '/action/:token' do
  respond_to_commits do |commit|
    GitHub.closed_issues(commit["message"]) do |issue|
      call env.merge("PATH_INFO" => '/reopen/#{issue}/#{commit["id"]}/#{commit["author"]["name"]}') unless commit["author"]["email"]==gitemail
      if commit["author"]["email"]==gitemail
        call env.merge("PATH_INFO" => '/noreopen/#{issue}/#{commit["author"]["name"]}')
      end 
    end
  end
end

post '/reopen/:issue/:commit_id/:commit_author' do
  call env.merge("PATH_INFO" => '/check_issue_label/#{params[:issue]}/Accepted')
  return "Issue Accepted" unless found=="false"

  call env.merge("PATH_INFO" => '/check_issue_label/#{params[:issue]}/New Issue')
  if found=="true"
    call env.merge("PATH_INFO" => '/re_label_issue/#{params[:issue]}/#{params[:commit_author]}')
    return "Do not Reopen for Review because Code is not Merged yet..."
  end
  if found=="false"
    call env.merge("PATH_INFO" => '/check_issue_label/#{params[:issue]}/Re-Opened')
    if found=="true"
      github.remove_issue_label params[:issue], "Re-Opened"
      github.add_issue_label params[:issue], "Again"
      return "Again Fixed by Developer"
    end
    call env.merge("PATH_INFO" => '/check_issue_label/#{params[:issue]}/Again')
    if found=="true"
      github.remove_issue_label params[:issue], "Again"
      github.add_issue_label params[:issue], "Re-Opened"
    end
    github.reopen_issue params[:issue]
    call env.merge("PATH_INFO" => '/comment/#{params[:issue]}/#{params[:commit_id]}')
    github.add_issue_label params[:issue], "Waiting For Review"
  end
end

post '/noreopen/:issue/:commit_author' do
  github.remove_issue_label params[:issue], "New Issue"
  github.add_issue_label params[:issue], params[:commit_author]
  github.add_issue_label params[:issue], "Accepted"
end

post '/check_issue_label/:issue/:label' do
  found = "false"
  github.view_issue_label params[:issue] do |labels|
    if labels==params[:label]
      found = "true"
    end
  end
end

post '/re_label_issue/:issue/:commiter' do
  github.remove_issue_label params[:issue], "New Issue"
  github.add_issue_label params[:issue], params[:commiter]
end

post '/comment/:issue/:commit_id' do
  comment = <<EOM
Issue referenced by #{params[:commit_id]} is reopening automatically for Review
EOM
  github.comment_issue params[:issue], comment
end