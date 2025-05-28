# frozen_string_literal: true

module Playtag
  module TagHandlers
    # Base class for all tag types
    class BaseTag
      # Initialize with a TagLib file object
      # @param file [TagLib::File] The TagLib file object
      def initialize(file)
        @file = file
      end

      # Read playtag tag from file
      # @return [String, nil] The playtag value or nil if not found
      def read
        raise NotImplementedError, 'Subclasses must implement read'
      end

      # Write playtag tag to file
      # @param tag_value [String] The playtag value to write
      # @return [Boolean] True if successful, false otherwise
      def write(tag_value)
        raise NotImplementedError, 'Subclasses must implement write'
      end

      # Check if debug mode is enabled
      # @return [Boolean] True if debug mode is enabled
      def debug?
        ENV['PLAYTAG_DEBUG'] == '1'
      end

      # Print debug message if debug mode is enabled
      # @param message [String] The debug message
      def debug(message)
        $stderr.puts message if debug?
      end

      # Print warning message
      # @param message [String] The warning message
      def warn(message)
        $stderr.puts "WARNING: #{message}"
      end
    end
  end
end
