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

        # Try to get the tag via item_list_map if available
        if @file.tag.respond_to?(:item_list_map)
          item_list_map = @file.tag.item_list_map
          if item_list_map.contains?(PLAYTAG_KEY)
            item = item_list_map[PLAYTAG_KEY]
            unless item.to_string_list.empty?
              value = item.to_string_list.first
              debug "Found PlayTag via item_list_map: #{value}"
              return value
            end
          end
        end

        # Fallback for older TagLib versions or different structure
        if @file.tag.respond_to?(:item_map)
          debug "Trying item_map method"
          begin
            if @file.tag.item_map.respond_to?(:[]) && @file.tag.item_map[PLAYTAG_KEY]
              value = @file.tag.item_map[PLAYTAG_KEY].to_string_list.first
              debug "Found PlayTag via item_map: #{value}"
              return value
            end
          rescue StandardError => e
            debug "Error accessing item_map: #{e.message}"
          end
        end

        debug "No PlayTag found"
        nil
      rescue StandardError => e
        warn "Error reading MP4 tags: #{e.message}"
        nil
      end

      # Write playtag tag to MP4
      # @param tag_value [String] The playtag value to write
      # @return [Boolean] True if successful, false otherwise
      def write(tag_value)
        debug "Writing MP4 tag: #{tag_value}"
        return false unless @file.tag

        begin
          # Try to use item_list_map if available
          if @file.tag.respond_to?(:item_list_map)
            item_list_map = @file.tag.item_list_map
            if tag_value.nil? || tag_value.strip.empty?
              if item_list_map.contains?(PLAYTAG_KEY)
                item_list_map.erase(PLAYTAG_KEY)
                debug 'Removed existing PlayTag'
              end
            else
              item = TagLib::MP4::Item.new([tag_value])
              item_list_map[PLAYTAG_KEY] = item
              debug 'Added new PlayTag via item_list_map'
            end
          # Fallback for older TagLib versions or different structure
          elsif @file.tag.respond_to?(:item_map)
            debug "Trying item_map method"
            if tag_value.nil? || tag_value.strip.empty?
              if @file.tag.respond_to?(:remove_item)
                begin
                  @file.tag.remove_item(PLAYTAG_KEY)
                  debug 'Removed existing PlayTag via remove_item'
                rescue StandardError => e
                  debug "Error removing item: #{e.message}"
                end
              end
            else
              begin
                item = TagLib::MP4::Item.new([tag_value])
                @file.tag.item_map[PLAYTAG_KEY] = item
                debug 'Added new PlayTag via item_map'
              rescue StandardError => e
                debug "Error setting item via item_map: #{e.message}"
                return false
              end
            end
          else
            warn "No supported method found to write MP4 tags"
            return false
          end

          # Save the file
          result = @file.save
          if !result
            warn "Error: Failed to save MP4 file"
            return false
          end
          return true
        rescue StandardError => e
          warn "Error writing MP4 tags: #{e.message}"
          return false
        end
      end
    end
  end
end
