require 'sinatra'
require 'yaml'
require 'json'
require 'octokit'

config = YAML::load(File.open('config.yml')) rescue {"user" => ENV["GITHUB_USERNAME"], "token" => ENV["GITHUB_PASSWORD"]}
Github_Client = Octokit::Client.new(:login => config['user'], :password => config['token'])

set :sessions, true
set :logging, true
set :port, 3000

def update_issue(repo, issue_id, options)
  puts "updating issue #{issue_id} with #{options}"
  Github_Client.post "/repos/#{repo}/issues/#{issue_id}", options
end

def closed?(github_issue)
  github_issue.state == 'closed'
end    


get '/test' do
  p 'hello world'
end

post '/' do
  push = JSON.parse(params[:payload])
  repo = "#{push['repository']['owner']['name']}/#{push['repository']['name']}"
  push['commits'].each do |c|
    m = c['message']
    issue_id = m.scan(/[^#]\#(\d+)(?:[^\d+]|\b)/)[0][0].to_i rescue nil
    next unless issue_id
    user = m.scan(/\=([a-zA-Z0-9]+)/)[0][0] rescue nil
    
    github_issue = Github_Client.issue(repo, issue_id)

    labels = m.scan(/\~([a-zA-Z0-9\-]+)/).flatten + github_issue.labels.map(&:name)
    labels << "pm-review" if !m.scan(/\#nopm/)[0] && closed?(github_issue) && push['ref'] == 'master'
    labels.uniq
    
    options = {:labels => labels}.merge(user ? {:assignee => user} : {})
    update_issue repo, issue_id, options
  end
end
