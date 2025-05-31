# frozen_string_literal: true

require_relative 'base_tag'
require 'nokogiri'
require 'open3'
require 'tempfile'

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
          xml_output, _ = Open3.capture2('mkvextract', 'tags', @file_path, err: debug_stream)
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
          error "Error reading MKV tags: #{e}"
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
          if tag_value.nil? || tag_value.strip.empty?
            # Extract existing tags
            xml_output, _ = Open3.capture2('mkvextract', 'tags', @file_path, err: debug_stream)
            
            if xml_output.nil? || xml_output.strip.empty?
              # No tags to clear
              debug 'No tags found in MKV file, nothing to clear'
              return true
            end
            
            # Parse XML
            doc = Nokogiri::XML(xml_output)
            
            # Find Tags element
            tags_element = doc.at_xpath('//Tags')
            if tags_element
              # Remove all playtag Tag elements
              tags_element.xpath('./Tag').each do |tag|
                tag.remove if is_playtag_tag_elt(tag)
              end

              # Write the modified tags back to the file
              write_to_file(doc)
            else
              debug 'No Tags element found in MKV file, nothing to clear'
              true
            end
          else
            # Extract existing tags or create a minimal structure
            xml_output, _ = Open3.capture2('mkvextract', 'tags', @file_path, err: debug_stream)
            xml_output = '<Tags></Tags>' if xml_output.nil? || xml_output.strip == ''

            # Parse XML
            doc = Nokogiri::XML(xml_output)

            with_get_or_create_elt(doc, 'Tags') do |tags|
              with_get_or_create_playtag_tag_elt(tags) do |tag|
                with_get_or_create_elt(tag.at_xpath("./Simple"), 'String') do |string|
                  string.content = tag_value
                end
              end
            end

            # Create a temporary file with the modified tags
            write_to_file(doc)
          end
        rescue StandardError => e
          error "Error writing MKV tags: #{e}"
          false
        end
      end

      # Clear playtag tag from MKV
      # @return [Boolean] True if successful
      def clear
        debug 'Clearing playtag from MKV file'
        write(nil)
      end

      private

      # Check if a tag is a PLAYTAG tag
      # @param tag [Nokogiri::XML::Node] Tag node
      # @return [Boolean] True if the tag is a PLAYTAG tag
      def is_playtag_tag_elt(tag)
        tag.xpath('./Simple').any? do |simple|
          simple.at_xpath('./Name')&.text == PLAYTAG_KEY
        end
      end

      # Get an element by name or create it if it doesn't exist
      # @param parent [Nokogiri::XML::Node] Parent node
      # @param element_name [String] Name of the element to find or create
      # @yield [element] Block to execute with the found or created element
      def with_get_or_create_elt(parent, element_name)
        element = parent.at_xpath("//#{element_name}")
        unless element
          element = Nokogiri::XML::Node.new(element_name, parent.document)
          parent.add_child(element)
        end
        yield element
      end

      # Get or create a Tag element with PLAYTAG
      # @param tags [Nokogiri::XML::Node] Tags parent node
      # @yield [tag] Block to execute with the found or created tag element
      def with_get_or_create_playtag_tag_elt(tags)
        # Iterate over all Tag children to find one with PLAYTAG_KEY
        tag = tags.xpath('./Tag').find(&method(:is_playtag_tag_elt))

        # If no suitable Tag found, create a new one with PLAYTAG
        unless tag
          tag = Nokogiri::XML::Node.new('Tag', tags.document)
          tags.add_child(tag)

          simple = Nokogiri::XML::Node.new('Simple', tags.document)
          tag.add_child(simple)
          
          name = Nokogiri::XML::Node.new('Name', tags.document)
          name.content = PLAYTAG_KEY
          simple.add_child(name)
        end

        yield tag
      end

      # Write the modified tags to a temporary file and apply them using mkvpropedit
      # @param doc [Nokogiri::XML::Document] The modified XML document
      # @return [Boolean] True if successful
      def write_to_file(doc)
        Tempfile.create(%w[playtag_mkv .xml]) do |temp_file|
          temp_file.write(doc.to_xml)
          temp_file.close

          # Apply the tags using mkvpropedit
          result = system('mkvpropedit', @file_path, '--tags', "all:#{temp_file.path}",
                          out: debug_stream, err: debug_stream)
          if result
            debug 'Successfully wrote PlayTag to MKV file'
            true
          else
            error 'Failed to write PlayTag to MKV file'
            false
          end
        end
      end

    end
  end
end
