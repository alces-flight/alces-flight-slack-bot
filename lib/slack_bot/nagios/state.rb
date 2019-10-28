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
module SlackBot
  class Nagios
    class State
      PROBLEM_TYPES = ["PROBLEM", "FLAPPINGSTART", "FLAPPINGDISABLED", "DOWNTIMESTART"]

      attr_reader :type, :state

      def initialize(type, state)
        @type = type
        @state = state
      end

      def to_s
        "*#{state}* #{icon}"
      end

      def problem?
        PROBLEM_TYPES.include?(type)
      end

      def ack?
        type == "ACKNOWLEDGEMENT"
      end

      def recovers?(s)
        !ack? && !problem? && s.problem?
      end

      def escalates?(s)
        s.state != 'OK' && state != s.state
      end

      def color
        case type
        when "PROBLEM", "FLAPPINGSTART"
          if state == 'UNKNOWN'
            '#666666'
          elsif state == 'WARNING'
            '#ff9900'
          else
            '#ff0000'
          end
        when "FLAPPINGDISABLED", "DOWNTIMESTART"
          '#ff9900'
        when "RECOVERY", "ACKNOWLEDGEMENT", "FLAPPINGSTOP", "DOWNTIMEEND", "DOWNTIMECANCELLED"
          '#00ff00'
        end
      end

      def icon_name
        case state
        when 'OK'
          'green_heart'
        when 'WARNING'
          'large_orange_diamond'
        when 'CRITICAL'
          'red_circle'
        when 'UNKNOWN'
          'question'
        when 'UP'
          'arrow_up'
        when 'DOWN'
          'arrow_down'
        when 'UNREACHABLE'
          'exclamation'
        end
      end

      def icon
        case state
        when 'OK'
          '💚'
        when 'WARNING'
          '🔶'
        when 'CRITICAL'
          '🔴'
        when 'UNKNOWN'
          '❓'
        when 'UP'
          '⬆️ 💚'
        when 'DOWN'
          '⬇️ 🔴'
        when 'UNREACHABLE'
          '❗'
        end
      end

      def ==(other)
        other.state == state && other.type == type
      end

      def hash
        [state, type].hash
      end
    end
  end
end
