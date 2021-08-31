# frozen_string_literal: true

module PumaCloudwatch
  class Metrics
    def self.start_sending(launcher)
      new(launcher).start_sending
    end

    def initialize(launcher)
      @launcher = launcher
    end

    def start_sending
      Looper.run(@launcher.options)
    end
  end
end
