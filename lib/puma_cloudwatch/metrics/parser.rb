# frozen_string_literal: true

module PumaCloudwatch
  class Metrics
    class Parser
      METRICS = {
        'backlog' => 'Backlog',
        'running' => 'Running',
        'pool_capacity' => 'PoolCapacity',
        'max_threads' => 'MaxThreads'
      }.freeze

      def call(stats)
        item = {
          'Backlog' => [],
          'Running' => [],
          'PoolCapacity' => [],
          'MaxThreads' => []
        }

        clustered = stats.key?("worker_status")

        if clustered
          statuses = stats["worker_status"].map { |s| s["last_status"] } # last_status: Array with worker stats
          statuses.each do |status|
            METRICS.each do |puma_metric_name, metric_name|
              count = status[puma_metric_name]
              item[metric_name] += [count] if count
            end
          end
        else # single mode
          METRICS.each do |puma_metric_name, metric_name|
            count = stats[puma_metric_name]
            item[metric_name] += [count] if count
          end
        end

        item
      end
    end
  end
end
