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
      puts gitemail
      puts commit["author"]["email"]
      puts "ReOpen" unless commit["author"]["email"]==gitemail
      if commit["author"]["email"]==gitemail
        puts "No ReOpen"
      end 
    end
  end
end

post '/reopen/:issue/:commit_id/:commit_author' do
  response = github.check_issue_label params[:issue], 'Accepted'
  return "Issue Accepted" unless response=="false"

  response = github.check_issue_label params[:issue], 'New Issue'
  if response=="true"
    github.re_label_issue params[:issue], params[:commit_author]
    return "Do not Reopen for Review because Code is not Merged yet..."
  end
  if response=="false"
    response = github.check_issue_label params[:issue], 'Re-Opened'
    if response=="true"
      github.remove_issue_label params[:issue], "Re-Opened"
      github.add_issue_label params[:issue], "Again"
      return "Again Fixed by Developer"
    end
    response = github.check_issue_label params[:issue], 'Again'
    if response=="true"
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

post '/comment/:issue/:commit_id' do
  comment = <<EOM
Issue referenced by #{params[:commit_id]} is reopening automatically for Review
EOM
  github.comment_issue params[:issue], comment
end