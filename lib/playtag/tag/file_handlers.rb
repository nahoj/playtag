# frozen_string_literal: true

require_relative '../logger'
require_relative 'id3v2_tag'
require_relative 'mkv_tag'
require_relative 'mp4_tag'
require_relative 'xiph_tag'
require 'fileutils'
require 'marcel'

module Playtag
  module TagHandlers
    # File handlers for different media types
    module FileHandlers
      extend Playtag::Logger

      # Process a file with the appropriate tag handler based on MIME type
      # @param file_path [String] Path to the file
      # @yield [BaseTag] The appropriate tag handler
      # @return [Object, nil] The result of the block
      def self.with_file_tag(file_path, &block)
        return nil unless block

        media_type = detect_media_type(file_path)
        debug "Detected media type: #{media_type}"

        case media_type
        when 'audio/flac', 'audio/x-flac'
          with_flac_file(file_path, &block)
        when 'video/webm', 'video/x-matroska'
          with_mkv_file(file_path, &block)
        when 'audio/mpeg'
          with_mp3_file(file_path, &block)
        when 'application/mp4', 'audio/mp4', 'video/mp4'
          with_mp4_file(file_path, &block)
        when 'application/ogg', 'audio/ogg', 'audio/vorbis', 'video/ogg'
          with_ogg_file(file_path, &block)
        else
          warn "Unsupported media type: #{media_type}"
          nil
        end
      end

      # Process a FLAC file with the given block
      # @param file_path [String] Path to the FLAC file
      # @yield [XiphTag] The Xiph tag handler
      # @return [Object] The result of the block
      def self.with_flac_file(file_path)
        TagLib::FLAC::File.open(file_path) do |file|
          yield XiphTag.new(file)
        end
      end

      # Process an MKV file with the given block
      # @param file_path [String] Path to the MKV file
      # @yield [MKVTag] The MKV tag handler
      # @return [Object] The result of the block
      def self.with_mkv_file(file_path)
        yield MKVTag.new(file_path)
      end

      # Process an MP3 file with the given block
      # @param file_path [String] Path to the MP3 file
      # @yield [ID3v2Tag] The ID3v2 tag handler
      # @return [Object] The result of the block
      def self.with_mp3_file(file_path)
        TagLib::MPEG::File.open(file_path) do |file|
          yield ID3v2Tag.new(file)
        end
      end

      # Process an MP4 file with the given block
      # @param file_path [String] Path to the MP4 file
      # @yield [MP4Tag] The MP4 tag handler
      # @return [Object] The result of the block
      def self.with_mp4_file(file_path)
        TagLib::MP4::File.open(file_path) do |file|
          yield MP4Tag.new(file)
        end
      end

      # Process an OGG file with the given block
      # @param file_path [String] Path to the OGG file
      # @yield [XiphTag] The Xiph tag handler
      # @return [Object] The result of the block
      def self.with_ogg_file(file_path)
        TagLib::Ogg::Vorbis::File.open(file_path) do |file|
          yield XiphTag.new(file)
        end
      end

      private

      def self.detect_media_type(file_path)
        Marcel::MimeType.for(File.open(file_path), name: File.basename(file_path))
      end
    end
  end
end
