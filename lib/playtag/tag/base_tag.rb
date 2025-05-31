# frozen_string_literal: true

require_relative '../logger'

module Playtag
  module TagHandlers
    # Base class for all tag types
    class BaseTag
      include Playtag::Logger

      # Initialize with a TagLib file object
      # @param file [TagLib::File] The TagLib file object
      def initialize(file)
        @file = file
        @file_path = file.respond_to?(:path) ? file.path : 'unknown_path'
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
    end
  end
end
