# frozen_string_literal: true

require_relative 'base_tag'

module Playtag
  module TagHandlers
    # Handler for Xiph Comment tags (OGG and FLAC files)
    class XiphTag < BaseTag
      # "The Ogg Vorbis comment specification does allow these key values to be
      # either upper or lower case. However, it is conventional for them to be
      # upper case. As such, TagLib, when parsing a Xiph/Vorbis comment,
      # converts all fields to uppercase."
      PLAYTAG_KEY = 'PLAYTAG'

      # Read playtag tag from Xiph Comment (OGG/FLAC)
      # @return [String, nil] The playtag value or nil if not found
      def read
        debug 'Reading Xiph Comment tags'
        
        tag = get_comment_tag
        return nil unless tag

        fields = tag.field_list_map
        
        if fields.key?(PLAYTAG_KEY)
          value_list = fields[PLAYTAG_KEY]
          if value_list.nil? || value_list.empty?
            debug "PlayTag key '#{PLAYTAG_KEY}' found but its value list is nil or empty."
          else
            value = value_list.first
            debug "Found PlayTag: #{value}"
            return value
          end
        else
          debug "PlayTag key '#{PLAYTAG_KEY}' not found in Xiph fields."
        end

        nil
      rescue StandardError => e
        error "Error reading Xiph Comment tags: #{e.message}"
        nil
      end

      # Write playtag tag to Xiph Comment (OGG/FLAC)
      # @param value [String, nil] The playtag value to write
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

        # According to TagLib::Ogg::XiphComment docs, add_field with replace=true
        # will replace all existing fields with that name
        if value.nil? || value.strip.empty?
          # If the field exists, remove it (clear tag)
          if tag.contains?(PLAYTAG_KEY)
            # According to docs, this will remove all fields with the given name
            tag.remove_fields(PLAYTAG_KEY)
            debug "Removed PLAYTAG field"
          end
        else
          # Add the field (this replaces any existing fields with the same name)
          tag.add_field(PLAYTAG_KEY, value, true)
          debug "Added/updated PLAYTAG field: #{value}"
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
          tag || (create ? @file.xiph_comment(true) : nil)
        elsif @file.is_a?(TagLib::Ogg::Vorbis::File)
          tag = @file.tag
          tag || (create ? @file.tag(true) : nil)
        else
          error "Unsupported file type for Xiph Comment: #{@file.class}"
          nil
        end
      end
    end
  end
end
