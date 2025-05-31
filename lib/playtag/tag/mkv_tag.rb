# frozen_string_literal: true

require_relative 'base_tag'
require 'tempfile'
require 'nokogiri'

module Playtag
  module TagHandlers
    # Handler for MKV (Matroska) tags using external mkvpropedit and mkvextract tools
    # Since TagLib doesn't natively support MKV tags, we use the mkvtoolnix utilities
    class MKVTag < BaseTag
      PLAYTAG_KEY = 'PLAYTAG'

      # Initialize with a file path instead of a TagLib file object
      # @param file_path [String] Path to the MKV file
      def initialize(file_path)
        @file_path = file_path
        @valid = File.exist?(@file_path)
        return if @valid

        error "MKV file not found: #{@file_path}"
      end

      # Read playtag tag from MKV
      # @return [String, nil] The playtag value or nil if not found
      def read
        debug 'Reading MKV tags'

        # Check if the file is valid
        return nil unless @valid

        begin
          # Extract tags using mkvextract (similar to Python implementation)
          xml_output = `mkvextract tags "#{@file_path}" 2>/dev/null`
          debug "mkvextract output length: #{xml_output.length} bytes"

          # If no tags, return nil
          if xml_output.nil? || xml_output.empty? || xml_output.strip == ''
            debug 'No tags found in MKV file'
            return nil
          end

          # Parse XML
          doc = Nokogiri::XML(xml_output)

          # Find the PLAYTAG element
          simple_tags = doc.xpath('//Simple')
          debug "Found #{simple_tags.length} simple tags"

          playtag_element = simple_tags.find do |simple|
            name_element = simple.at_xpath('./Name')
            name_element && name_element.text == PLAYTAG_KEY
          end

          if playtag_element
            # Get the String element within the Simple element
            string_element = playtag_element.at_xpath('./String')
            if string_element && !string_element.text.empty?
              value = string_element.text
              debug "Found PlayTag: #{value}"
              return value
            end
          end

          debug 'No PlayTag found'
          nil
        rescue StandardError => e
          error "Error reading MKV tags: #{e.message}"
          nil
        end
      end

      # Write playtag tag to MKV
      # @param tag_value [String, nil] The playtag value to write
      # @return [Boolean] True if successful, false otherwise
      def write(tag_value)
        debug "Writing MKV tag: #{tag_value}"

        # Check if the file is valid
        unless @valid
          error "MKV file '#{@file_path}' is not considered valid. Aborting write."
          return false
        end

        begin
          # Extract existing tags or create a minimal structure
          xml_output = `mkvextract tags "#{@file_path}" 2>/dev/null`
          xml_output = '<Tags><Tag></Tag></Tags>' if xml_output.nil? || xml_output.strip == ''

          # Parse XML
          doc = Nokogiri::XML(xml_output)

          if tag_value.nil? || tag_value.strip.empty?
            # For clearing the tag, we'll take the simple approach - just remove all tags
            # This avoids the error with empty <Tag> elements
            doc = Nokogiri::XML('<Tags></Tags>')

            # Apply the empty tags using mkvpropedit
            temp_file = Tempfile.new(%w[playtag_mkv .xml])
            begin
              temp_file.write(doc.to_xml)
              temp_file.close

              # Apply the empty tags using mkvpropedit, redirect both stdout and stderr to null
              result = system('mkvpropedit', @file_path, '--tags', "all:#{temp_file.path}",
                              out: File::NULL, err: File::NULL)
              if result
                debug 'Successfully cleared PlayTag from MKV file'
                true
              else
                error 'Failed to clear PlayTag from MKV file'
                false
              end
            ensure
              temp_file.unlink
            end
          else
            # Get the first Tag element (or create one if not exists)
            tag_element = doc.at_xpath('//Tag')
            unless tag_element
              tags_element = doc.at_xpath('//Tags')
              if tags_element
                # Create a new Tag element inside existing Tags
                tag_element = Nokogiri::XML::Node.new('Tag', doc)
                tags_element.add_child(tag_element)
              else
                # Create a new Tags root element
                doc = Nokogiri::XML('<Tags><Tag></Tag></Tags>')
                tag_element = doc.at_xpath('//Tag')
              end
            end

            # Find existing PLAYTAG element or create a new one
            playtag_element = doc.xpath('//Simple').find do |simple|
              name_element = simple.at_xpath('./Name')
              name_element && name_element.text == PLAYTAG_KEY
            end

            if playtag_element
              # Update existing String element
              string_element = playtag_element.at_xpath('./String')
              if string_element
                string_element.content = tag_value
              else
                # Create String element if it doesn't exist
                string_element = Nokogiri::XML::Node.new('String', doc)
                string_element.content = tag_value
                playtag_element.add_child(string_element)
              end
            else
              # Create a new Simple element
              playtag_element = Nokogiri::XML::Node.new('Simple', doc)
              tag_element.add_child(playtag_element)

              # Add Name element
              name_element = Nokogiri::XML::Node.new('Name', doc)
              name_element.content = PLAYTAG_KEY
              playtag_element.add_child(name_element)

              # Add String element
              string_element = Nokogiri::XML::Node.new('String', doc)
              string_element.content = tag_value
              playtag_element.add_child(string_element)
            end

            # Create a temporary file with the modified tags
            temp_file = Tempfile.new(%w[playtag_mkv .xml])
            begin
              temp_file.write(doc.to_xml)
              temp_file.close

              # Apply the tags using mkvpropedit
              result = system('mkvpropedit', @file_path, '--tags', "all:#{temp_file.path}",
                              out: File::NULL, err: File::NULL)
              if result
                debug 'Successfully wrote PlayTag to MKV file'
                true
              else
                error 'Failed to write PlayTag to MKV file'
                false
              end
            ensure
              temp_file.unlink
            end
          end
        rescue StandardError => e
          error "Error writing MKV tags: #{e.message}"
          false
        end
      end

      # Clear playtag tag from MKV
      # @return [Boolean] True if successful
      def clear
        debug 'Clearing playtag from MKV file'
        write(nil)
      end
    end
  end
end
