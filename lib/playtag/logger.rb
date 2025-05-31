# frozen_string_literal: true

require 'logger'

module Playtag
  # Central logging module for Playtag
  module Logger
    # Initialize the logger
    @logger = ::Logger.new($stderr)
    @logger.formatter = proc do |severity, _datetime, _progname, msg|
      prefix = severity == 'DEBUG' ? '' : "#{severity}: "
      "#{prefix}#{msg}\n"
    end
    @logger.level = ENV['PLAYTAG_DEBUG'] == '1' ? ::Logger::DEBUG : ::Logger::INFO

    # Define module functions that can be directly included or extended
    module_function

    # Print debug message
    # @param message [String] The message to log
    def debug(message)
      Playtag::Logger.instance_variable_get(:@logger).debug(message)
    end

    # Print info message
    # @param message [String] The message to log
    def info(message)
      Playtag::Logger.instance_variable_get(:@logger).info(message)
    end

    # Print warning message
    # @param message [String] The warning message to log
    def warn(message)
      Playtag::Logger.instance_variable_get(:@logger).warn(message)
    end

    # Print error message
    # @param message [String] The error message to log
    def error(message)
      Playtag::Logger.instance_variable_get(:@logger).error(message)
    end

    # Print fatal message
    # @param message [String] The fatal message to log
    def fatal(message)
      Playtag::Logger.instance_variable_get(:@logger).fatal(message)
    end

    # Update log level based on debug flag
    def update_log_level
      Playtag::Logger.instance_variable_get(:@logger).level = ENV['PLAYTAG_DEBUG'] == '1' ? ::Logger::DEBUG : ::Logger::INFO
    end
  end
end
