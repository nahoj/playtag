# frozen_string_literal: true

require_relative 'base_tag'

module Playtag
  module TagHandlers
    # Handler for MP4 tags
    class MP4Tag < BaseTag
      PLAYTAG_KEY = '----:com.apple.iTunes:PlayTag'

      # Read playtag tag from MP4
      # @return [String, nil] The playtag value or nil if not found
      def read
        debug 'Reading MP4 tags'
        return nil unless @file.tag

        if @file.tag.respond_to?(:item_map)
          debug 'Trying item_map method for reading'
          begin
            item_map = @file.tag.item_map
            item = item_map[PLAYTAG_KEY] # Directly access the item

            if item && !item.to_string_list.empty?
              value = item.to_string_list.first
              debug "Found PlayTag via item_map: #{value}"
              return value
            else
              debug "PlayTag key '#{PLAYTAG_KEY}' not found in item_map or its value is empty."
            end
          rescue StandardError => e
            debug "Error accessing item_map for reading: #{e.message}"
          end
        else
          error 'MP4 tag object does not support item_map'
        end

        debug 'No PlayTag found'
        nil
      rescue StandardError => e
        error "Error reading MP4 tags: #{e.message}"
        nil
      end

      # Write playtag tag to MP4
      # @param tag_value [String, nil] The playtag value to write
      # @return [Boolean] True if successful, false otherwise
      def write(tag_value)
        debug "Writing MP4 tag: #{tag_value}"

        # Check if the TagLib file object itself is considered valid.
        if @file.respond_to?(:valid?) && !@file.valid?
          error "MP4 file '#{@file_path}' is not considered valid by TagLib. Aborting write."
          return false
        end

        return false unless @file.tag

        begin
          if @file.tag.respond_to?(:item_map)
            debug 'Trying item_map method for writing'
            item_map = @file.tag.item_map # Get the map proxy

            if tag_value.nil? || tag_value.strip.empty?
              # Remove the tag
              if @file.tag.contains(PLAYTAG_KEY)
                @file.tag.remove_item(PLAYTAG_KEY)
                debug 'Removed existing PlayTag via remove_item'
              else
                debug 'PlayTag not found, no removal needed.'
              end
            else
              # Add or update the tag
              # Create a new MP4 item with string list
              item = TagLib::MP4::Item.new([tag_value])
              @file.tag[PLAYTAG_KEY] = item
              debug 'Set PlayTag via []= operator'
            end
          else
            error 'MP4 tag object does not support item_map for writing'
            return false
          end

          # Save the file
          result = @file.save
          unless result
            error 'Failed to save MP4 file'
            return false
          end
          true
        rescue StandardError => e
          error "Error writing MP4 tags: #{e.message}"
          false
        end
      end
      
      # Clear playtag tag from MP4
      # @return [Boolean] True if successful
      def clear
        debug 'Clearing playtag tag from MP4 file'
        return false unless @file.tag

        # Check if the file is valid before attempting to write
        unless @file.valid?
          error "TagLib reports MP4 file is invalid, aborting tag clear"
          return false
        end

        # Same as write with nil value
        write(nil)
      end
    end
  end
end
