# frozen_string_literal: false

require "logger"

module Logging
  def logger
    Logging.logger
  end

  def self.logger
    @logger ||= Logger.new($stdout)
    @logger.formatter = proc do |severity, datetime, _progname, msg|
      datefmt = datetime.strftime("%Y-%m-%d %H:%M:%S")
      # ensure that there is only one newline at the end of the message
      "#{severity} [#{datefmt}]: #{msg}\n".gsub!(/\n+/, "\n")
    end
    @logger
  end

  def self.log_level
    # default to only showing errors
    ENV.fetch("RUBY_LOG_LEVEL", "ERROR")
  end

  logger.level = log_level
end
