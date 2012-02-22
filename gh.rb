require 'sinatra'
require 'yaml'
require 'json'
require 'octokit'

config = YAML::load(File.open('config.yml')) rescue {"user" => ENV["GITHUB_USERNAME"], "token" => ENV["GITHUB_PASSWORD"]}
Github_Client = Octokit::Client.new(:login => config['user'], :password => config['token'])

set :sessions, true
set :logging, true
set :port, 3000

def get_labels(user, repo, issue)
    endpoint = options.gh_issue.gsub(':user', user).gsub(':repo', repo).gsub(':number', issue)
    c = Curl::Easy.new(options.gh_api + endpoint)
    c.http_auth_types = :basic
    c.username = options.gh_user
    c.password = options.gh_token
    c.perform
    json = JSON.parse(c.body_str)
    json['issue']['labels']
end

def add_label(user, repo, issue, label)
    endpoint = options.gh_add_label.gsub(':user', user).gsub(':repo', repo).gsub(':number', issue).gsub(':label', label)
    c = Curl::Easy.new(options.gh_api + endpoint)
    c.http_auth_types = :basic
    c.username = options.gh_user
    c.password = options.gh_token
    c.perform
    p c.body_str
end

def assign_issue(repo, issue_id, assignee)
  issue = Github_Client.issue(issue) rescue nil
  Github_Client.update_issue repo, issue_id, :assignee => assignee
end

get '/test' do
  p 'hello world'
end

post '/' do
    push = JSON.parse(params[:payload])
    repo = "#{push['repository']['owner']['name']}/#{push['repository']['name']}"
    push['commits'].each do |c|
        m = c['message']
        issue = m.scan(/[^#]\#(\d+)[^\d+]/)[0]
        next unless issue
        begin 
          user = m.scan(/\=[a-zA-Z0-9]+/)[0].split(//)[1..-1].join
          assign_issue(repo, issue_id, user)
        rescue => e
          p e.to_s
        end
        # labels = m.scan(/\~[a-zA-Z0-9]+/)
        # labels.each do |l| 
        #   add_label(owner, repo, issue[0], l.gsub('~', ''))
        # end
    end
end
