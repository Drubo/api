require 'rubygems'
require 'httparty'

module HTTParty
  class Request
    def path=(uri)
      @path = URI.parse(URI.escape(uri))
    end
  end
end

class GitHub
  include HTTParty
  base_uri "https://github.com/api/v2/json"
  
  def initialize(repo, user=nil, pass=nil)
    @user = user
    @pass = pass
    @repo = repo
  end

  def label_issue(issue, label)
    self.class.post("/issues/label/add/#{@user}/#{@repo}/#{label}/#{issue}", options)
  end
  
  def remove_issue_label(issue, label)
    self.class.post("/issues/label/remove/#{@user}/#{@repo}/#{label}/#{issue}", options)
  end

  def reopen_issue(issue)
    self.class.post("/issues/reopen/#{@user}/#{@repo}/#{issue}", options)
  end

  def comment_issue(issue, comment)
    options[:body] = {"comment" => comment}
    self.class.post("/issues/comment/#{@user}/#{@repo}/#{issue}", options)
  end
  
  def view_issue(issue)
    issue_info = JSON.parse(self.class.post("/issues/show/#{@user}/#{@repo}/#{issue}", options))
    issue_info["labels"].each do |label|
      yield label
    end
  end

  def self.issue(message)
    message[/gh-(\d+)/i,1]
  end

  def self.closed_issues(message)
    issues = message.scan(/(closes|fixes|closed|fixed) (gh-|#)(\d+)/i).map{|m| m[2]}
    return issues unless block_given?
    issues.each{ |issue| yield(issue) }
  end

  def self.nonclosing_issues(message)
    issues = message.scan(/(closes|fixes|closed|fixed)? (gh-|#)(\d+)/i).
      select{|m| m[0].nil? && m[1] != "#"}.
      map{|m| m[2]}
    return issues unless block_given?
    issues.each{ |issue| yield(issue) }
  end

  private
    def options
      @options ||= @user.nil? ? {} : { :basic_auth => {:username => @user+"/token", :password => @pass}}
    end
end
