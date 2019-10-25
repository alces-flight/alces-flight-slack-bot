#!/usr/bin/ruby
require 'net/http'
require 'uri'
require 'yaml'

h = if ARGV[0] == "--host"
      hostname = ARGV[1]
      state = ARGV[2]
      output = ARGV[3]
      type = ARGV[4]
      {
        "type" => "nagios",
        "notificationtype" => type,
        "hostname" => hostname,
        "hoststate" => state,
        "notificationtype" => type,
        "hostoutput" => output,
      }
    elsif ARGV[0] == "--service"
      hostname = ARGV[1]
      desc = ARGV[2]
      state = ARGV[3]
      output = ARGV[4]
      type = ARGV[5]
      {
        "type" => "nagios",
        "notificationtype" => type,
        "hostname" => hostname,
        "servicestate" => state,
        "servicedesc" => desc,
        "notificationtype" => type,
        "serviceoutput" => output,
      }
    end

if h.nil?
  puts "Unknown notice type: #{ARGV[0]}"
  exit 1
else
  uri = URI.parse("http://localhost:9292/message")
  # Create the HTTP objects
  http = Net::HTTP.new(uri.host, uri.port)
  request = Net::HTTP::Post.new(uri.request_uri)
  request.body = h.to_yaml
  # Send the request
  response = http.request(request)
  puts response.code
  puts response.body
end
