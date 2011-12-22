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
  
  def found
    @found = "false"
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
    call env.merge("PATH_INFO" => '/reopen/'+commit["message"]+'/'+commit["author"]["name"]+'/'+commit["id"]) unless commit["author"]["email"]==gitemail
    if commit["author"]["email"]==gitemail
      call env.merge("PATH_INFO" => '/noreopen/'+commit["message"]+'/'+commit["author"]["name"])
    end 
  end
end

post '/reopen/:commit_message/:commit_author/:commit_id' do
  GitHub.closed_issues(params[:commit_message]) do |issue|
    call env.merge("PATH_INFO" => '/check_issue_label/'+issue+'/Accepted')
    return "Issue Accepted" if found=="true"

    call env.merge("PATH_INFO" => '/check_issue_label/'+issue+'/New Issue')
    if found=="true"
      call env.merge("PATH_INFO" => '/re_label_issue/'+issue+'/'+params[:commit_author])
      return "Do not Reopen for Review because Code is not Merged yet..."
    end
    if found=="false"
      call env.merge("PATH_INFO" => '/check_issue_label/'+issue+'/Re-Opened')
      if found=="true"
        github.remove_issue_label issue, "Re-Opened"
        github.add_issue_label issue, "Again"
        return "Again Fixed by Developer"
      end
      call env.merge("PATH_INFO" => '/check_issue_label/'+issue+'/Again')
      if found=="true"
        github.remove_issue_label issue, "Again"
        github.add_issue_label issue, "Re-Opened"
      end
      github.reopen_issue issue
      call env.merge("PATH_INFO" => '/comment/'+issue+'/'+params[:commit_id])
      github.add_issue_label issue, "Waiting For Review"
    end
  end
end

post '/noreopen/:commit_message/:commit_author' do
  GitHub.closed_issues(params[:commit_message]) do |issue|
    github.remove_issue_label issue, "New Issue"
    github.add_issue_label issue, params[:commit_author]
    github.add_issue_label issue, "Accepted"
  end
end

get '/check_issue_label/:issue/:label' do
  found = "false"
  github.view_issue_label params[:issue] do |labels|
    if labels==params[:label]
      found = "true"
    end
  end
  return found
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