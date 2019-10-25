$LOAD_PATH.unshift(File.join(File.dirname(__FILE__),'lib'))

require 'slack_bot/app'

Slack.configure do |config|
  config.token = ENV['SLACK_API_TOKEN']
end

run SlackBot::App
