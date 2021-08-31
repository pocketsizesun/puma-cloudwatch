# frozen_string_literal: true

module PumaCloudwatch
  class Metrics
    class Looper
      def self.run(options)
        new(options).run
      end

      def initialize(options)
        @options = options
        @control_url = options[:control_url]
        @control_auth_token = options[:control_auth_token]
        @frequency = Integer(ENV['PUMA_CLOUDWATCH_FREQUENCY'] || 60)
        @enabled = ENV['PUMA_CLOUDWATCH_ENABLED'] || false
      end

      def run
        raise StandardError, "Puma control app is not activated" if @control_url == nil

        puts(message) unless ENV['PUMA_CLOUDWATCH_MUTE_START_MESSAGE']
        Thread.new do
          perform
        end
      end

      def message
        message = "puma-cloudwatch plugin: Will send data every #{@frequency} seconds."
        unless @enabled
          to_enable = "To enable set the environment variable PUMA_CLOUDWATCH_ENABLED=1"
          message = "Disabled: #{message}\n#{to_enable}"
        end
        message
      end

    private

    def perform
      sender = Sender.new
      fetcher = Fetcher.new(@options)
      parser = Parser.new
      loop do
        begin
          stats = fetcher.call
          metrics = parser.call(stats)
          sender.call(metrics) unless metrics.empty?
        rescue Exception => e
          puts "Error reached top of looper: #{e.message} (#{e.class})"
        end

        sleep @frequency
      end
    end

      def enabled?
        !!@enabled
      end
    end
  end
end
