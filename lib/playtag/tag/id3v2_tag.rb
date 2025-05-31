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
        tag = @file.id3v2_tag # Changed back: do not create if not present for read
        return nil unless tag

        # Find the TXXX frame with description PLAYTAG
        # Based on successful logic from direct_taglib_test.rb
        frames = tag.frame_list('TXXX')
        if frames.nil? || frames.empty?
          debug 'No TXXX frames found.'
          return nil
        end

        playtag_frame = frames.find { |f| f.description&.upcase == PLAYTAG_DESCRIPTION.upcase }

        if playtag_frame
          # For TXXX frames, the value is typically the last string in the field_list
          # field_list usually contains [Encoding, Description, Value]
          # Alternatively, frame.text might work for some taglib-ruby versions if it's simpler.
          # Sticking to field_list.last for now as per direct_taglib_test.rb
          if playtag_frame.field_list && playtag_frame.field_list.size > 1 # Ensure there's a value part
            value = playtag_frame.field_list.last.to_s
            debug "Found PlayTag TXXX frame: #{value}"
            return value
          else
            debug 'PlayTag TXXX frame found, but its field_list is unexpected or empty.'
            return nil
          end
        else
          debug "No TXXX frame with description '#{PLAYTAG_DESCRIPTION}' found."
        end

        nil
      rescue StandardError => e
        error "Error reading ID3v2 tags: #{e}"
        nil
      end

      # Write playtag tag to ID3v2 (MP3)
      # @param tag_value [String, nil] The playtag value to write
      # @return [Boolean] True if successful, false otherwise
      def write(tag_value)
        debug "Writing ID3v2 tag: #{tag_value}"

        # Check if the TagLib file object itself is considered valid.
        if @file.respond_to?(:valid?) && !@file.valid?
          error "MP3/ID3v2 file '#{@file_path}' is not considered valid by TagLib. Aborting write."
          return false
        end

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
            error "Error creating TXXX frame: #{e}"
            return false
          end
        end

        # Save the file
        result = @file.save
        unless result
          error 'Failed to save ID3v2 file'
          return false
        end

        true
      rescue StandardError => e
        error "Error writing ID3v2 tags: #{e}"
        false
      end

      # Clear playtag tag from ID3v2 (MP3)
      # @return [Boolean] True if successful
      def clear
        debug 'Clearing playtag from ID3v2 tag'

        # Check if the file is valid before attempting to write
        unless @file.valid?
          error 'TagLib reports ID3v2 file is invalid, aborting tag clear'
          return false
        end

        # Same as write with nil value
        write(nil)
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

          frames_to_remove << frame if frame.description == PLAYTAG_DESCRIPTION
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
