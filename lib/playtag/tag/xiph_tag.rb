# frozen_string_literal: true

require_relative 'base_tag'

module Playtag
  module TagHandlers
    # Handler for Xiph Comment tags (OGG and FLAC files)
    class XiphTag < BaseTag
      PLAYTAG_KEY = 'PLAYTAG'

      # Read playtag tag from Xiph Comment (OGG/FLAC)
      # @return [String, nil] The playtag value or nil if not found
      def read
        debug 'Reading Xiph Comment tags'
        
        tag = get_comment_tag
        return nil unless tag

        # Try various methods to read the tag
        if tag.respond_to?(:field_list_map) && tag.field_list_map.respond_to?(:[])
          field_values = tag.field_list_map[PLAYTAG_KEY]
          if field_values && !field_values.empty?
            value = field_values.first
            debug "Found PlayTag via field_list_map: #{value}"
            return value
          end
        end

        if tag.respond_to?(:field)
          field_values = tag.field(PLAYTAG_KEY)
          unless field_values.empty?
            value = field_values.first
            debug "Found PlayTag via field method: #{value}"
            return value
          end
        end

        # For TagLib versions that use all uppercase key names
        if tag.respond_to?(:field)
          field_values = tag.field('PLAYTAG')
          unless field_values.empty?
            value = field_values.first
            debug "Found PlayTag via uppercase field method: #{value}"
            return value
          end
        end

        # Direct property access for some versions
        if tag.respond_to?(PLAYTAG_KEY.downcase.to_sym)
          value = tag.send(PLAYTAG_KEY.downcase.to_sym)
          if value && !value.empty?
            debug "Found PlayTag via direct property: #{value}"
            return value
          end
        end

        debug "No PlayTag found"
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
        
        tag = get_comment_tag
        return false unless tag

        # Try to remove the existing tag using different methods
        if tag.respond_to?(:remove_fields)
          tag.remove_fields(PLAYTAG_KEY)
          debug 'Removed existing PlayTag fields via remove_fields'
        elsif tag.respond_to?(:remove_field)
          tag.remove_field(PLAYTAG_KEY)
          debug 'Removed existing PlayTag field via remove_field'
        end

        # Also try removing with uppercase key
        if tag.respond_to?(:remove_fields)
          tag.remove_fields('PLAYTAG')
          debug 'Removed existing uppercase PlayTag fields'
        elsif tag.respond_to?(:remove_field)
          tag.remove_field('PLAYTAG')
          debug 'Removed existing uppercase PlayTag field'
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
