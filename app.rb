require_relative 'session'

require 'rack/app'
require 'rack/app/front_end'
require 'json'
require 'cgi'

class App < Rack::App
  apply_extensions :front_end

  serve_files_from '/static'

  helpers do
    def h(v)
      CGI.escapeHTML(v)
    end
  end

  layout 'layout.html.erb'

  get '/' do
    @sessions = Session.all
    render 'index.html.erb'
  end

end
