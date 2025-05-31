# frozen_string_literal: true

require_relative '../logger'
require_relative 'mp4_tag'
require_relative 'id3v2_tag'
require_relative 'xiph_tag'
require 'mime/types'

module Playtag
  module TagHandlers
    # File handlers for different media types
    module FileHandlers
      extend Playtag::Logger

      # Process a file with the appropriate tag handler based on MIME type
      # @param file_path [String] Path to the file
      # @yield [BaseTag] The appropriate tag handler
      # @return [Object] The result of the block
      def self.with_file_tag(file_path)
        media_type = detect_media_type(file_path)
        debug "MIME type detected: #{media_type}"

        case media_type
        when 'audio/mpeg'
          with_mp3_file(file_path) { |tag| yield tag if block_given? }
        when 'application/mp4', 'video/mp4', 'audio/mp4'
          with_mp4_file(file_path) { |tag| yield tag if block_given? }
        when 'audio/ogg'
          with_ogg_file(file_path) { |tag| yield tag if block_given? }
        when 'audio/flac'
          with_flac_file(file_path) { |tag| yield tag if block_given? }
        else
          warn "Unsupported file format: #{media_type}"
          nil
        end
      end

      # Process an MP4 file with the given block
      # @param file_path [String] Path to the MP4 file
      # @yield [MP4Tag] The MP4 tag handler
      # @return [Object] The result of the block
      def self.with_mp4_file(file_path)
        TagLib::MP4::File.open(file_path) do |file|
          handler = MP4Tag.new(file)
          yield handler if block_given?
        end
      end

      # Process an MP3 file with the given block
      # @param file_path [String] Path to the MP3 file
      # @yield [ID3v2Tag] The ID3v2 tag handler
      # @return [Object] The result of the block
      def self.with_mp3_file(file_path)
        TagLib::MPEG::File.open(file_path) do |file|
          handler = ID3v2Tag.new(file)
          yield handler if block_given?
        end
      end

      # Process an OGG file with the given block
      # @param file_path [String] Path to the OGG file
      # @yield [XiphTag] The Xiph tag handler
      # @return [Object] The result of the block
      def self.with_ogg_file(file_path)
        TagLib::Ogg::Vorbis::File.open(file_path) do |file|
          handler = XiphTag.new(file)
          yield handler if block_given?
        end
      end

      # Process a FLAC file with the given block
      # @param file_path [String] Path to the FLAC file
      # @yield [XiphTag] The Xiph tag handler
      # @return [Object] The result of the block
      def self.with_flac_file(file_path)
        TagLib::FLAC::File.open(file_path) do |file|
          handler = XiphTag.new(file)
          yield handler if block_given?
        end
      end

      # Detect the media type of a file
      # @param file_path [String] Path to the file
      # @return [String] MIME type of the file
      def self.detect_media_type(file_path)
        mime_types = MIME::Types.type_for(file_path)
        mime_type = mime_types.first&.content_type || 'application/octet-stream'

        # Special case for MP4
        if mime_type == 'application/octet-stream' && file_path.end_with?('.mp4', '.m4v')
          mime_type = 'application/mp4'
        end

        # Special case for OGG (might be detected as audio/vorbis)
        if (mime_type == 'audio/vorbis' || file_path.end_with?('.ogg')) && !mime_type.start_with?('audio/ogg')
          mime_type = 'audio/ogg'
        end

        # Special case for FLAC
        if mime_type == 'application/octet-stream' && file_path.end_with?('.flac')
          mime_type = 'audio/flac'
        end

        mime_type
      end
    end
  end
end
