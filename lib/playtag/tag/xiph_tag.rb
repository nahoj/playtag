# frozen_string_literal: true

require_relative 'base_tag'

module Playtag
  module TagHandlers
    # Handler for Xiph Comment tags (OGG and FLAC files)
    class XiphTag < BaseTag
      PLAYTAG_KEY = 'playtag'

      # Read playtag tag from Xiph Comment (OGG/FLAC)
      # @return [String, nil] The playtag value or nil if not found
      def read
        debug 'Reading Xiph Comment tags'
        
        tag = get_comment_tag
        return nil unless tag

        fields = tag.field_list_map
        # Vorbis comment field names are case-insensitive.
        # taglib-ruby's field_list_map might normalize keys (e.g., to uppercase).
        # To ensure compatibility (e.g., with playtag-python/mutagen which also normalizes),
        # we check for our canonical key in uppercase.
        # PLAYTAG_KEY is 'playtag'. We check for 'PLAYTAG'.
        upcased_key = PLAYTAG_KEY.upcase

        if fields.key?(upcased_key)
          value_list = fields[upcased_key]
          if value_list.nil? || value_list.empty?
            debug "PlayTag key '#{upcased_key}' found but its value list is nil or empty."
          else
            value = value_list.first
            debug "Found PlayTag (as #{upcased_key}): #{value}"
            return value
          end
        else
          # If debug output is desired for all keys when not found:
          # debug "PlayTag key '#{upcased_key}' (nor variants) not found in Xiph fields: #{fields.keys.sort.join(', ')}"
          debug "PlayTag key '#{upcased_key}' not found in Xiph fields."
        end

        nil
      rescue StandardError => e
        warn "Error reading Xiph Comment tags: #{e.message}"
        nil
      end

      # Write playtag tag to Xiph Comment (OGG/FLAC)
      # @param tag_value [String] The playtag value to write
      # @return [Boolean] True if successful, false otherwise
      def write(tag_value)
        debug "Writing Xiph Comment tag: #{tag_value}"

        # Check if the TagLib file object itself is considered valid.
        if @file.respond_to?(:valid?) && !@file.valid?
          warn "Xiph-tagged file '#{@file_path}' is not considered valid by TagLib. Aborting write."
          return false
        end

        tag = get_comment_tag
        return false unless tag

        # Remove the existing tag. PLAYTAG_KEY is already lowercase 'playtag'.
        # TagLib 2.0 removes Ogg::XiphComment::removeField(), recommends removeFields().
        if tag.respond_to?(:remove_fields)
          tag.remove_fields(PLAYTAG_KEY)
          debug "Removed existing PlayTag fields for key '#{PLAYTAG_KEY}' via remove_fields"
        else
          # This case should ideally not be hit if using a modern taglib-ruby with TagLib 1.x or 2.x
          # as remove_fields is generally available.
          warn "Xiph comment tag does not respond to remove_fields. Cannot reliably remove old tag."
          # Not returning false here, as we might still be able to add the new one.
        end

        # Add new field if tag_value is not empty
        unless tag_value.nil? || tag_value.strip.empty?
          success = false
          
          # Try different methods of adding the field
          if tag.respond_to?(:add_field)
            tag.add_field(PLAYTAG_KEY, tag_value)
            debug 'Added new PlayTag field via add_field'
            success = true
          end
          
          # Try direct field map access if add_field didn't work
          if !success && tag.respond_to?(:field_list_map) && tag.field_list_map.respond_to?(:[]=)
            tag.field_list_map[PLAYTAG_KEY] = [tag_value]
            debug 'Added new PlayTag field via field_list_map'
            success = true
          end

          # Try as a simple property setter if all else fails
          if !success && tag.respond_to?(:"#{PLAYTAG_KEY.downcase}=")
            tag.send(:"#{PLAYTAG_KEY.downcase}=", tag_value)
            debug 'Added new PlayTag field via property setter'
            success = true
          end
          
          return false unless success
        end

        # Save the file
        @file.save
      rescue StandardError => e
        warn "Error writing Xiph Comment tags: #{e.message}"
        false
      end

      private

      # Get the Xiph Comment tag from the file
      # @return [TagLib::Ogg::XiphComment, TagLib::FLAC::XiphComment, nil] The comment tag
      def get_comment_tag
        # Direct tag access
        if @file.respond_to?(:tag) && @file.tag
          return @file.tag
        end
        
        # For OGG Vorbis files using newer TagLib
        if @file.respond_to?(:xiph_comment) && @file.xiph_comment
          return @file.xiph_comment
        end
        
        # For FLAC files with vorbis_comment
        if @file.respond_to?(:vorbis_comment) && @file.vorbis_comment
          return @file.vorbis_comment
        end
        
        # For alternate OGG structure
        if @file.respond_to?(:comment) && @file.comment
          return @file.comment
        end
        
        warn "Could not find a valid tag interface for this file"
        nil
      end
    end
  end
end
