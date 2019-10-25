# coding: utf-8
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
require 'tty-config'

module SlackBot
  module Config
    class << self
      def data
        @data ||= TTY::Config.new.tap do |cfg|
          cfg.append_path(File.join(root, 'etc'))
          begin
            cfg.read
          rescue TTY::Config::ReadError
            nil
          end
        end
      end

      def root
        @root ||= File.expand_path(File.join(__dir__, '..', '..'))
      end

      def clusters
        @clusters ||= data.fetch(
          :clusters,
          default: {}
        )
      end

      def channel
        @channel ||= data.fetch(
          :channel,
          default: '#markt-test'
        )
      end

      def backoff
        @backoff ||= data.fetch(
          :channel,
          default: 5
        )
      end

      def max_backoff
        @max_backoff ||= data.fetch(
          :max_backoff,
          default: 15
        )
      end
    end
  end
end
