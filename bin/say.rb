#!/usr/bin/ruby
require 'net/http'
require 'uri'
require 'yaml'

h = {
  "type" => "say",
  "channel" => ARGV.shift,
  "text" => ARGV.shift || ARGF.read
}

uri = URI.parse("http://localhost:9292/message")
# Create the HTTP objects
http = Net::HTTP.new(uri.host, uri.port)
request = Net::HTTP::Post.new(uri.request_uri)
request.body = h.to_yaml
# Send the request
response = http.request(request)
puts response.code
puts response.body
