# frozen_string_literal: true

require_relative 'base_tag'

module Playtag
  module TagHandlers
    # Handler for ID3v2 tags (MP3 files)
    class ID3v2Tag < BaseTag
      PLAYTAG_FRAME_ID = 'TXXX'
      PLAYTAG_DESCRIPTION = 'PLAYTAG'

      # Read playtag tag from ID3v2 (MP3)
      # @return [String, nil] The playtag value or nil if not found
      def read
        debug 'Reading ID3v2 tags'
        return nil unless @file.respond_to?(:id3v2_tag) && @file.id3v2_tag

        id3v2_tag = @file.id3v2_tag
        frame_list = id3v2_tag.frame_list(PLAYTAG_FRAME_ID)
        frame_list.each do |frame|
          next unless frame.respond_to?(:description) && frame.respond_to?(:text)
          
          if frame.description == PLAYTAG_DESCRIPTION
            value = frame.text
            debug "Found PlayTag: #{value}"
            return value
          end
        end

        debug 'No PlayTag found'
        nil
      rescue StandardError => e
        warn "Error reading ID3v2 tags: #{e.message}"
        nil
      end

      # Write playtag tag to ID3v2 (MP3)
      # @param tag_value [String] The playtag value to write
      # @return [Boolean] True if successful, false otherwise
      def write(tag_value)
        debug "Writing ID3v2 tag: #{tag_value}"
        return false unless @file.respond_to?(:id3v2_tag) && @file.id3v2_tag

        id3v2_tag = @file.id3v2_tag
        # Remove existing PLAYTAG frames
        remove_playtag_frames

        # Add the tag value unless it's nil or empty
        unless tag_value.nil? || tag_value.strip.empty?
          begin
            # Create a new UserTextIdentificationFrame
            frame = TagLib::ID3v2::UserTextIdentificationFrame.new
            frame.description = PLAYTAG_DESCRIPTION
            frame.text = tag_value
            id3v2_tag.add_frame(frame)
            debug 'Added new PlayTag frame'
          rescue StandardError => e
            warn "Error creating TXXX frame: #{e.message}"
            return false
          end
        end

        # Save the file
        @file.save
      rescue StandardError => e
        warn "Error writing ID3v2 tags: #{e.message}"
        false
      end

      private

      # Remove all existing PLAYTAG frames
      def remove_playtag_frames
        return unless @file.respond_to?(:id3v2_tag) && @file.id3v2_tag

        id3v2_tag = @file.id3v2_tag
        # Find frames to remove
        frames_to_remove = []
        frame_list = id3v2_tag.frame_list(PLAYTAG_FRAME_ID)
        
        frame_list.each do |frame|
          next unless frame.respond_to?(:description)
          
          if frame.description == PLAYTAG_DESCRIPTION
            frames_to_remove << frame
          end
        end

        # Remove the frames
        frames_to_remove.each do |frame|
          id3v2_tag.remove_frame(frame)
        end

        debug "Removed #{frames_to_remove.size} existing PlayTag frames"
      end
    end
  end
end
