# frozen_string_literal: true

require_relative 'base_tag'

module Playtag
  module TagHandlers
    # Handler for Xiph Comment tags (OGG and FLAC files)
    class XiphTag < BaseTag
      PLAYTAG_KEY = 'playtag' # Case-sensitive for Xiph comments

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
      # @param value [String] The playtag value to write
      # @return [Boolean] True if successful
      def write(value)
        debug "Writing playtag '#{value}' to Xiph Comment tag"
        
        # Check if the file is valid before attempting to write
        unless @file.valid?
          error "TagLib reports Xiph-based file is invalid, aborting tag write"
          return false
        end
        
        tag = get_comment_tag(true) # Create if not present
        return false unless tag

        # Remove existing field (case insensitive in Xiph comments)
        tag.remove_field(PLAYTAG_KEY.upcase)
        
        # Add new field if value is present
        unless value.nil? || value.strip.empty?
          tag.add_field(PLAYTAG_KEY.upcase, value)
          debug "Added PlayTag field to Xiph Comment"
        end
        
        # Save the file
        result = @file.save
        unless result
          error "Failed to save Xiph Comment file"
          return false
        end
        
        true
      rescue StandardError => e
        warn "Error writing Xiph Comment tag: #{e.message}"
        false
      end
      
      # Clear playtag tag from Xiph Comment (OGG/FLAC)
      # @return [Boolean] True if successful
      def clear
        debug "Clearing playtag from Xiph Comment tag"
        
        # Check if the file is valid before attempting to write
        unless @file.valid?
          error "TagLib reports Xiph-based file is invalid, aborting tag clear"
          return false
        end
        
        # Same as write with nil value
        write(nil)
      end

      private

      # Get the Xiph Comment tag object
      # @param create [Boolean] Whether to create the tag if it doesn't exist
      # @return [TagLib::Ogg::XiphComment, nil] The tag object
      def get_comment_tag(create = false)
        if @file.is_a?(TagLib::FLAC::File)
          tag = @file.xiph_comment
          return tag || (create ? @file.xiph_comment(true) : nil)
        elsif @file.is_a?(TagLib::Ogg::Vorbis::File)
          tag = @file.tag
          return tag || (create ? @file.tag(true) : nil) 
        else
          error "Unsupported file type for Xiph Comment: #{@file.class}"
          return nil
        end
      end
    end
  end
end
