# frozen_string_literal: true

# It probably makes sense to configure PUMA_CLOUDWATCH_DIMENSION_VALUE to include your application name.
# For example if you're application is named "myapp", this would be a good value to use:
#
#    PUMA_CLOUDWATCH_DIMENSION_VALUE=myapp-puma
#
# Then you can get all the metrics for the pool_capacity for your myapp-puma app.
#
# Summing the metric tells you the total available pool_capacity for the myapp-puma app.
#
module PumaCloudwatch
  class Metrics
    class Sender
      def initialize
        @namespace = ENV['PUMA_CLOUDWATCH_NAMESPACE'] || "WebServer"
        @dimension_name = ENV['PUMA_CLOUDWATCH_DIMENSION_NAME'] || "App"
        @dimension_value = ENV['PUMA_CLOUDWATCH_DIMENSION_VALUE'] || "puma"
        @enabled = ENV['PUMA_CLOUDWATCH_ENABLED'] || false
        @dimensions = [
          {
            name: @dimension_name,
            value: @dimension_value
          },
          {
            name: 'Host',
            value: Socket.gethostname
          }
        ]
      end

      def call(metrics)
        put_metric_data(
          namespace: @namespace,
          metric_data: build_metric_data(metrics)
        )
      end

      # Input @metrics example:
      #
      #     [{:backlog=>[0, 0],
      #     :running=>[0, 0],
      #     :pool_capacity=>[16, 16],
      #     :max_threads=>[16, 16]}]
      #
      # Output example:
      #
      #   [{:metric_name=>"backlog",
      #     :statistic_values=>{:sample_count=>2, :sum=>0, :minimum=>0, :maximum=>0}},
      #   {:metric_name=>"running",
      #     :statistic_values=>{:sample_count=>2, :sum=>0, :minimum=>0, :maximum=>0}},
      #   {:metric_name=>"pool_capacity",
      #     :statistic_values=>{:sample_count=>2, :sum=>32, :minimum=>16, :maximum=>16}},
      #   {:metric_name=>"max_threads",
      #     :statistic_values=>{:sample_count=>2, :sum=>32, :minimum=>16, :maximum=>16}}]
      #
      # Resources:
      # pool_capcity and max_threads are the important metrics
      # https://dev.to/amplifr/monitoring-puma-web-server-with-prometheus-and-grafana-5b5o
      #
      def build_metric_data(metrics)
        metric_data = metrics.collect do |metric_name, values|
          {
            metric_name: metric_name,
            dimensions: @dimensions,
            statistic_values: {
              sample_count: values.length,
              sum: values.sum,
              minimum: values.min,
              maximum: values.max
            }
          }
        end

        metric_data << build_busy_percentage_metric_datum(metrics)

        metric_data
      end

      private

      def build_busy_percentage_metric_datum(metrics)
        values = []

        metrics['Running'].length.times do |i|
          values << (1.0 - metrics['PoolCapacity'][i].to_f / metrics['MaxThreads'][i].to_f) * 100.0
        end

        {
          metric_name: 'LoadAverage',
          dimensions: @dimensions,
          statistic_values: {
            sample_count: values.length,
            sum: values.sum,
            minimum: values.min,
            maximum: values.max
          }
        }
      end

      def put_metric_data(params)
        if ENV['PUMA_CLOUDWATCH_DEBUG']
          message = "sending data to cloudwatch:"
          message = "NOOP: #{message}" unless enabled?
          puts message
          pp params
        end

        if enabled?
          begin
            cloudwatch.put_metric_data(params)
          rescue Aws::CloudWatch::Errors::AccessDenied => e
            puts "WARN: #{e.class} #{e.message}"
            puts "Unable to send metrics to CloudWatch"
          rescue PumaCloudwatch::Error => e
            puts "WARN: #{e.class} #{e.message}"
            puts "Unable to send metrics to CloudWatch"
          end
        end
      end

      def enabled?
        !!@enabled
      end

      def cloudwatch
        @cloudwatch ||= Aws::CloudWatch::Client.new
      rescue Aws::Errors::MissingRegionError => e
        # Happens when:
        #   1. ~/.aws/config is not also setup locally
        #   2. On EC2 instance when AWS_REGION not set
        puts "WARN: #{e.class} #{e.message}"
        raise PumaCloudwatch::Error.new(e.message)
      end
    end
  end
end
