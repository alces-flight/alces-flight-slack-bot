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
require_relative '../slack'
require_relative '../config'

module SlackBot
  class Nagios
    class Poster
      class << self
        attr_accessor :last

        def clusters
          YAML.load_file(File.expand_path(File.join(__FILE__,'..','..','..','..','etc','clusters.yml')))
        end

        def warning(ex)
          Slack.client.chat_postMessage(
            channel: Config.channel,
            icon_emoji: ':bug:',
            username: "Bug report",
            as_user: false,
            text: "Erk!\n#{$!.message}\n\`\`\`\n#{$!.backtrace.join("\n")}\n\`\`\`\n"
          )
        end
        
        def update_ongoing(channel, ts, statements)
          statements.each do |s|
            ex = ongoing[s[:subject]]
            if ex
              if s[:state].recovers?(ex[:state])
                # add emoji reaction and remove ongoing
                ex[:ts].each do |rts|
                  begin
                    Slack.client.reactions_add(
                      channel: channel,
                      name: 'green_heart',
                      timestamp: rts
                    )
                  rescue
                    warning($!) unless $!.message == 'already_reacted'
                  end
                end
                ongoing.delete(s[:subject])
              elsif s[:state].escalates?(ex[:state])
                # add emoji reaction and update ongoing
                ex[:ts].each do |rts|
                  begin
                    Slack.client.reactions_add(
                      channel: channel,
                      name: s[:state].icon_name,
                      timestamp: rts
                    )
                  rescue
                    warning($!) unless $!.message == 'already_reacted'
                  end
                end
                ongoing[s[:subject]] = {
                  counter: 1,
                  state: s[:state],
                  ts: [ts]
                  
                }
              elsif ex[:state] == s[:state]
                # increment counter
                ex[:counter] += 1
                ex[:ts] << ts unless ex[:ts].include?(ts)
              end
            elsif s[:state].problem?
              ongoing[s[:subject]] = {
                counter: 1,
                state: s[:state],
                ts: [ts]
              }
            end
          end
        end

        def ongoing
          @ongoing ||= {}
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
      def last_message_covers_statements?
        last_subjects = (self.class.last || {})[:subjects] || []
        @statements.all? do |s|
          last_subjects.include?(
            {
              subject: s[:subject],
              state: s[:state]
            }
          )
        end
      end

      def last_message_immediately_recovered?
        if @statements.all? {|s| !s[:state].ack? && !s[:state].problem?}
          last_subjects = (self.class.last || {})[:subjects] || []
          @statements.all? do |s|
            last_subjects.any? do |ls|
              ls[:subject] == s[:subject]
            end
          end
        end
      end

      def add_thread_response
        # add thread
        text = ""
        @statements.each do |s|
          text << "#{bullet_for(s[:subject], s[:state])}#{s[:subject]} is #{s[:state]}"
          unless s[:output].nil? || s[:output] == ""
            text << " (_#{s[:output]}_)"
          end
          text << "\n"
        end
        Slack.client.chat_postMessage(
          channel: Config.channel,
          text: text,
          icon_emoji: cluster_emoji,
          username: cluster_name,
          as_user: false,
          thread_ts: self.class.last[:ts]
        )
        self.class.update_ongoing(self.class.last[:channel], self.class.last[:ts], @statements)
      end

      def update_initial_response
        Slack.client.chat_update(
          channel: self.class.last[:channel],
          text: "*<#{cluster_link}|##{cluster}>*",
          fallback: "*<#{cluster_link}|##{cluster}>*",
          attachments: self.class.last[:attachments].concat(create_attachments(include_ts: true)),
          ts: self.class.last[:ts]
        )
        self.class.update_ongoing(self.class.last[:channel], self.class.last[:ts], @statements)
      end

      def create_poster_thread
        Thread.new do
          sleep @backoff
          if last_message_immediately_recovered?
            update_initial_response
          elsif last_message_covers_statements?
            add_thread_response
          else
            attachments = create_attachments
            response = Slack.client.chat_postMessage(
              channel: Config.channel,
              attachments: attachments,
              text: "*<#{cluster_link}|##{cluster}>*",
              fallback: "*<#{cluster_link}|##{cluster}>*",
              as_user: false,
              icon_emoji: cluster_emoji,
              username: cluster_name,
            )
            self.class.update_ongoing(response.channel, response.ts, @statements)
            self.class.last = {
              ts: response.ts,
              channel: response.channel,
              subjects: problem_subjects,
              attachments: attachments
            }
          end
        rescue
          self.class.warning($!)
        ensure
          @statements.clear
          @backoff = 5
        end
      end

      def problem_subjects
        @statements.map do |s|
          if s[:state].problem?
            {
              subject: s[:subject],
              state: s[:state]
            }
          end
        end.compact
      end

      def create_attachments(include_ts: false)
        {}.tap do |h|
          @statements.each do |s|
            c = s[:state].color
            a = h[c]
            if a.nil?
              a = h[c] = {
                fallback: "",
                color: c,
                text: "",
                mrkdwn_in: ["text"]
              }.tap do |o|
                o[:ts] = Time.now.to_i if include_ts
              end
            end
            a[:text] << "#{bullet_for(s[:subject],s[:state])}#{s[:subject]} is #{s[:state]}"
            unless s[:output].nil? || s[:output] == ""
              a[:text] << " (_#{s[:output]}_)"
            end
            a[:text] << "\n"
          end
        end.values.each do |a|
          a[:fallback] = a[:text]
        end
      end

      def bullet_for(subject, state)
        if ex = self.class.ongoing[subject]
          if ex[:state] == state
            c = ex[:counter] + 1
            emoji_number_for(c.to_s) + " "
          elsif state.problem?
            "🆕 "
          elsif state.ack?
            "✅ *ACKNOWLEDGED* "
          else
            "✳️  "
          end
        elsif state.problem?
          "🆕 "
        elsif state.ack?
          "✅ *ACKNOWLEDGED* "
        else
          "✳️  "
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

      def cluster_link
        "https://flightcenter-nagios2.flightcenter.alces-flight.com/nagios/cgi-bin/status.cgi?hostgroup=#{cluster}&style=detail"
      end

      def emoji_number_for(s)
        s.split('').map do |n|
          "#{n}\uFE0F\u20E3"
        end.join('')
      end
    end
  end
end
