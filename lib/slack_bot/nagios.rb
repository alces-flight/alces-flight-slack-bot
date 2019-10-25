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
require_relative 'slack'
require_relative 'config'

module SlackBot
  class Nagios
    class << self
      def posters
        @posters ||= {}
      end
    end

    KEYS = {
      host: [
        'hostname',
        'notificationtype',
        'hostoutput',
      ],
      service: [
        'hostname',
        'notificationtype',
        'servicedesc',
        'serviceoutput',
      ],
    }

    def initialize(data)
      @data = data
    end

    # HOSTNAME
    # Short name for the host (i.e. "biglinuxbox"). This value is
    # taken from the host_name directive in the host definition.
    
    # NOTIFICATIONTYPE
    # A string identifying the type of notification that is being sent
    # ("PROBLEM", "RECOVERY", "ACKNOWLEDGEMENT", "FLAPPINGSTART",
    # "FLAPPINGSTOP", "FLAPPINGDISABLED", "DOWNTIMESTART",
    # "DOWNTIMEEND", or "DOWNTIMECANCELLED").

    # SERVICEDESC
    # The long name/description of the service (i.e. "Main
    # Website"). This value is taken from the service_description
    # directive of the service definition.

    # SERVICESTATE
    # A string indicating the current state of the service ("OK",
    # "WARNING", "UNKNOWN", or "CRITICAL").

    # SERVICEOUTPUT
    # The first line of text output from the last service check
    # (i.e. "Ping OK").

    # HOSTSTATE
    # A string indicating the current state of the host ("UP", "DOWN",
    # or "UNREACHABLE").

    # HOSTOUTPUT
    # The first line of text output from the last host check
    # (i.e. "Ping OK").

    def process
      assert_valid
      @hostname = @data['hostname']
      @type = @data['notificationtype']
      if @data.key?('hoststate')
        @state = @data['hoststate']
        @output = @data['hostoutput']
      else
        @state = @data['servicestate']
        @output = @data['serviceoutput']
        @desc = @data['servicedesc']
      end
      (
        self.class.posters[cluster] ||=
        Poster.new(cluster)
      ).add(statement)
    end

    def cluster
      @cluster ||= @hostname.split('.').last
    end

    def statement
      {
        type: @type,
        state: @state,
        output: @output,
      }.tap do |h|
        if @desc
          h[:subject] = "Service *#{host}/#{@desc}*"
        else
          h[:subject] = "Host *#{host}*"
        end
      end
    end

    def host
      @host ||= @hostname.split('.')[0]
    end

    private
    def assert_valid
      if @data.key?('hoststate')
        KEYS[:host].each do |k|
          raise "Key missing for host message: #{k}" unless @data.key?(k)
        end
      elsif @data.key?('servicestate')
        KEYS[:service].each do |k|
          raise "Key missing for service message: #{k}" unless @data.key?(k)
        end
      else
        raise "Neither host nor service message"
      end
    end

    class Poster
      class << self
        def clusters
          YAML.load_file(File.expand_path(File.join(__FILE__,'..','..','..','etc','clusters.yml')))
        end
      end

      attr_reader :cluster

      def initialize(cluster)
        @cluster = cluster
        @backoff = Config.backoff.to_i
        @statements = []
      end

      def add(statement)
        @statements << statement
        if @poster_thread.nil? || !@poster_thread.alive?
          @poster_thread = create_poster_thread
        elsif @backoff < Config.max_backoff.to_i && @poster_thread.alive?
          @backoff += Config.backoff.to_i
          @poster_thread.kill
          @poster_thread = create_poster_thread
        end
      end

      private
      def create_poster_thread
        Thread.new do
          sleep @backoff
          Slack.client.chat_postMessage(
            channel: Config.channel,
            attachments: create_attachments,
            as_user: false,
            icon_emoji: cluster_emoji,
            username: cluster_name,
          )
          @statements.clear
          @backoff = 5
        end
      end

      def create_attachments
        {}.tap do |h|
          @statements.each do |s|
            c = color_for(s[:type], s[:state])
            a = h[c]
            if a.nil?
              a = h[c] = {
                fallback: "",
                color: c,
                text: "",
                mrkdwn_in: ["text"]
              }
            end
            a[:text] << text_for(s[:subject], s[:state])
            unless s[:output].nil? || s[:output] == ""
              a[:text] << " (_#{s[:output]}_)"
            end
            a[:text] << "\n"
          end
        end.values.each do |a|
          a[:text] = "*<#{cluster_link}|##{cluster}>*\n#{a[:text]}"
          a[:fallback] = a[:text]
        end
      end

      def cluster_name
        @cluster_name ||=
          Config.clusters[cluster] && Config.clusters[cluster]['name'] ||
          cluster
      end

      def cluster_emoji
        @cluster_emoji ||=
          Config.clusters[cluster] && Config.clusters[cluster]['emoji'] ||
          ':computer:'
      end

      def text_for(subject, state)
        "#{subject} is *#{state}* #{icon_for(state)}"
      end

      def cluster_link
        "https://flightcenter-nagios2.flightcenter.alces-flight.com/nagios/cgi-bin/status.cgi?hostgroup=#{cluster}&style=detail"
      end

      def icon_for(state)
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
          '⬆️'
        when 'DOWN'
          '⬇️'
        when 'UNREACHABLE'
          '❗'
        end
      end

      def color_for(type, state)
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
    end
  end
end
