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
  default_params :output => 'json'
  format :json
  
  def initialize(repo, user=nil, pass=nil)
    @user = user
    @pass = pass
    @repo = repo
  end

  def add_issue_label(issue, label)
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
  
  def view_issue_label(issue)
    issue_info = self.class.get("/issues/show/#{@user}/#{@repo}/#{issue}", options)
    issue_info["issue"]["labels"].each do |label|
      yield label
    end
  end
  
  def check_issue_label(issue, label)
    found = "false"
    view_issue_label issue do |labels|
      if labels==label
        found = "true"
      end
    end
    return found
  end
  
  def re_label_issue(issue, commiter, label_to_remove)
    remove_issue_label issue, label_to_remove
    add_issue_label issue, commiter
  end
  
  def noreopen(issue, commit_author)
    remove_issue_label issue, "New Issue"
    add_issue_label issue, commit_author
    add_issue_label issue, "Accepted"
  end

  def reopen(issue, commit_id, commit_author, ref)
    response = check_issue_label issue, 'Accepted'
    return "Issue Accepted" unless response=="false"
  
    response = check_issue_label issue, 'Waiting For Review'
    if response=="true"
      if ref != "refs/heads/master"
        re_label_issue issue, commit_author, 'Waiting For Review'
        response = check_issue_label issue, 'Re-Opened'
        if response=="true"
          remove_issue_label issue, "Re-Opened"
          add_issue_label issue, "Again"
        end
        return "Do not Reopen for Review because New Code is not Merged yet..."
      else
        reopen_issue issue
      end
    end

    response = check_issue_label issue, 'New Issue'
    if response=="true"
      if ref != "refs/heads/master"
        re_label_issue issue, commit_author, 'New Issue'
        return "Do not Reopen for Review because Code is not Merged yet..."
      end
    end
    if response=="false"
      if ref != "refs/heads/master"
        response = check_issue_label issue, 'Re-Opened'
        if response=="true"
          remove_issue_label issue, "Re-Opened"
          add_issue_label issue, "Again"
          return "Again Fixed by Developer"
        end
      end
      if ref == "refs/heads/master"
        response = check_issue_label issue, 'Again'
        if response=="true"
          remove_issue_label issue, "Again"
          add_issue_label issue, "Re-Opened"
        end
        reopen_issue issue
        comment issue, commit_id
        add_issue_label issue, "Waiting For Review"
      end
    end
  end
  
  def comment(issue, commit_id)
    comment = "Issue referenced by #{commit_id} is reopening automatically for Review"
    comment_issue issue, comment
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
