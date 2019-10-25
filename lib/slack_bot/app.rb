#==============================================================================
# Copyright (C) 2019-present Alces Flight Ltd.
#
# This file is part of Flight Slack Bot.
#
# This program and the accompanying materials are made available under
# the terms of the Eclipse Public License 2.0 which is available at
# <https://www.eclipse.org/legal/epl-2.0>, or alternative license
# terms made available by Alces Flight Ltd - please direct inquiries
# about licensing to licensing@alces-flight.com.
#
# Flight Slack Bot is distributed in the hope that it will be useful, but
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, EITHER EXPRESS OR
# IMPLIED INCLUDING, WITHOUT LIMITATION, ANY WARRANTIES OR CONDITIONS
# OF TITLE, NON-INFRINGEMENT, MERCHANTABILITY OR FITNESS FOR A
# PARTICULAR PURPOSE. See the Eclipse Public License 2.0 for more
# details.
#
# You should have received a copy of the Eclipse Public License 2.0
# along with Flight Slack Bot. If not, see:
#
#  https://opensource.org/licenses/EPL-2.0
#
# For more information on Flight Slack Bot, please visit:
# https://github.com/alces-flight/flight-slack-bot
#==============================================================================
require_relative 'version'
require_relative 'message'

require 'rack/app'
require 'rack/app/front_end'
require 'cgi'

module SlackBot
  class App < Rack::App
    apply_extensions :front_end

    serve_files_from '/static'

    helpers do
      def h(v)
        CGI.escapeHTML(v)
      end
    end

    layout '/views/layout.html.erb'

    get '/' do
      render '/views/index.html.erb'
    end

    post '/message' do
      d = request.body.read
      result = Message.process(d)
      response.status = 400 if !result.success?
      result.content + "\n"
    end
  end
end
