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

  def open_issue(payload)
    options[:body] = {"title" => "Payload", "body" => payload}
    self.class.post("/issues/open/#{@user}/#{@repo}", options)
  end
  
  def add_issue_label(issue, label)
    self.class.post("/issues/label/add/nibssolutions/#{@repo}/#{label}/#{issue}", options)
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
    issue_info = self.class.get("/issues/show/nibssolutions/#{@repo}/#{issue}", options)
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
  
  def re_label_issue(issue, label_to_add, label_to_remove)
    remove_issue_label issue, label_to_remove
    add_issue_label issue, label_to_add
  end
  
  def noreopen(issue)
    response = check_issue_label issue, 'Status - Fixed'
    return "Fixed" unless response=="false"
    
    add_issue_label issue, "Status - Needs Review"
  end

  def reopen(issue, commit_id, commit_author, ref, pusher, commiteremail)
    response = check_issue_label issue, 'Accepted'
    return "Issue Accepted" unless response=="false"
  
    response = check_issue_label issue, 'Waiting For Review'
    if response=="true"
      if ref != "refs/heads/master"
        if pusher==commiteremail
          re_label_issue issue, commit_author, 'Waiting For Review'
          response = check_issue_label issue, 'Re-Opened'
          if response=="true"
            re_label_issue issue, "Again", "Re-Opened"
          end
          return "Do not Reopen for Review because New Code is not Merged yet..."
        end
      end
    end

    response = check_issue_label issue, 'New Issue'
    if response=="true"
      if ref != "refs/heads/master"
        if pusher==commiteremail
          re_label_issue issue, commit_author, 'New Issue'
          return "Do not Reopen for Review because Code is not Merged yet..."
        end
      end
    end
    if response=="false"
      if ref != "refs/heads/master"
        if pusher==commiteremail
          response = check_issue_label issue, 'Re-Opened'
          if response=="true"
            re_label_issue issue, "Again", "Re-Opened"
            return "Again Fixed by Developer"
          end
        end
      end
      if ref == "refs/heads/master"
        response = check_issue_label issue, 'Again'
        if response=="true"
          re_label_issue issue, "Re-Opened", "Again"
        end
        response = check_issue_label issue, 'Waiting For Review'
        if response!="true"
          add_issue_label issue, "Waiting For Review"
          comment issue, commit_id
        end
        reopen_issue issue
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
      @options ||= @user.nil? ? {} : { :basic_auth => {:username => @user, :password => @pass}}
    end
end
