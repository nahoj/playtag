# frozen_string_literal: true

require 'fileutils'
require 'taglib'
require 'mime/types'
require_relative 'logger'
require_relative 'tag/file_handlers'

module Playtag
  # Main Tag class for reading and writing playtag tags
  class Tag
    # Include Logger methods directly
    extend Playtag::Logger

    # Read playtag tag from a file
    # @param file_path [String] Path to the file
    # @return [String, nil] The playtag value or nil if not found
    def self.read(file_path)
      unless File.exist?(file_path)
        warn "File not found: #{file_path}"
        return nil
      end

      tag_value = TagHandlers::FileHandlers.with_file_tag(file_path) do |handler|
        handler.read
      end

      if tag_value.nil?
        info "No playtag tag found in #{file_path}"
      else
        debug "Read playtag tag: #{tag_value}"
      end

      tag_value
    end

    # Write playtag tag to a file
    # @param file_path [String] Path to the file
    # @param tag_value [String, nil] The playtag value to write, or nil to clear the tag
    # @return [Boolean] True if successful, false otherwise
    def self.write(file_path, tag_value)
      unless File.exist?(file_path)
        warn "File not found: #{file_path}"
        return false
      end

      debug "Writing playtag tag to #{file_path}: #{tag_value}"
      result = TagHandlers::FileHandlers.with_file_tag(file_path) do |handler|
        handler.write(tag_value)
      end

      result
    end

    # Clear playtag tag from a file
    # @param file_path [String] Path to the file
    # @return [Boolean] True if successful, false otherwise
    def self.clear(file_path)
      unless File.exist?(file_path)
        warn "File not found: #{file_path}"
        return false
      end

      debug "Clearing playtag tag from #{file_path}"
      result = TagHandlers::FileHandlers.with_file_tag(file_path) do |handler|
        handler.clear
      end

      result
    end

    # Parse a playtag string into a hash of options.
    # Mirrors playtag-python's str_opts_of_tag and parse_opt_str.
    # @param tag_string [String] The playtag string (e.g., "v1;t=10-20;vol=+3dB")
    # @return [Hash<String, String>] Parsed options
    def self.parse_tag_to_options(tag_string)
      return {} if tag_string.nil? || tag_string.strip.empty?

      parts = tag_string.strip.split(/\s*;\s*/)

      # Remove version part if present (e.g., "v1")
      parts.shift if parts.first&.match?(/^v\d[\d.]*$/i)

      options = {}
      boolean_opts = ['mirror'] # Add other boolean options here if any

      parts.each do |part|
        next if part.strip.empty?

        match_data = part.match(/^\s*([^=]+?)\s*=\s*(.+)\s*$/)
        if match_data
          key = match_data[1].strip
          value = match_data[2].strip
          options[key] = value
        elsif boolean_opts.include?(part.strip.downcase)
          options[part.strip.downcase] = 'true'
        else
          warn "Invalid playtag option format: #{part}"
        end
      end

      debug "Parsed playtag options: #{options}"
      options
    end

    # Parse a time string (HH:MM:SS.ss or SS.ss) into seconds.
    # Mirrors playtag-python's parse_time.
    # @param time_string [String, nil] The time string
    # @return [Float, Integer, nil] Time in seconds, or nil if parsing fails
    def self.parse_time(time_string)
      return nil if time_string.nil? || time_string.strip.empty?

      if time_string.include?(':')
        parts = time_string.split(':').reverse # SS.ss, MM, HH
        seconds = parts[0].to_f
        seconds += parts[1].to_i * 60 if parts.length > 1
        seconds += parts[2].to_i * 3600 if parts.length > 2
        seconds
      else
        time_string.to_f
      end
    rescue StandardError => e
      warn "Error parsing time string '#{time_string}': #{e.message}"
      nil
    end

    # Check if debug mode is enabled
    # @return [Boolean] True if debug mode is enabled
    def self.debug?
      ENV['PLAYTAG_DEBUG'] == '1'
    end
  end
end
