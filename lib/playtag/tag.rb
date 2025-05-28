# frozen_string_literal: true

require 'fileutils'
require 'taglib'
require 'mime/types'

require_relative 'tag/file_handlers'

module Playtag
  # Main Tag class for reading and writing playtag tags
  class Tag
    # Read playtag tag from a file
    # @param file_path [String] Path to the file
    # @return [String, nil] The playtag value or nil if not found
    def self.read(file_path)
      unless File.exist?(file_path)
        warn "File not found: #{file_path}"
        return nil
      end

      tag_value = nil
      TagHandlers::FileHandlers.with_file_tag(file_path) do |handler|
        tag_value = handler.read
      end

      unless tag_value
        warn "No playtag tag found"
        return nil
      end
      
      tag_value
    end

    # Write playtag tag to a file
    # @param file_path [String] Path to the file
    # @param tag_value [String] The playtag value to write
    # @return [Boolean] True if successful, false otherwise
    def self.write(file_path, tag_value)
      unless File.exist?(file_path)
        warn "File not found: #{file_path}"
        return false
      end

      success = false
      TagHandlers::FileHandlers.with_file_tag(file_path) do |handler|
        success = handler.write(tag_value)
      end

      success
    end

    # Detect the media type of a file
    # @param file_path [String] Path to the file
    # @return [String] MIME type of the file
    def self.detect_media_type(file_path)
      TagHandlers::FileHandlers.detect_media_type(file_path)
    end

    # Check if debug mode is enabled
    # @return [Boolean] True if debug mode is enabled
    def self.debug?
      ENV['PLAYTAG_DEBUG'] == '1'
    end

    # Print debug message if debug mode is enabled
    # @param message [String] The debug message
    def self.debug(message)
      $stderr.puts message if debug?
    end

    # Print warning message
    # @param message [String] The warning message
    def self.warn(message)
      $stderr.puts "WARNING: #{message}"
    end
  end
end
