module Playtag
  class Tag
    PLAYTAG_KEY = "----:com.apple.iTunes:PlayTag"

    # Read playtag tag from file
    def self.read(file_path)
      unless File.exist?(file_path)
        warn "Error: File not found: #{file_path}"
        return nil
      end

      # Detect file type using MIME type
      media_type = detect_media_type(file_path)
      
      case media_type
      when :mp4
        read_mp4_tags(file_path)
      when :mp3
        read_mp3_tags(file_path)
      when :flac
        read_flac_tags(file_path)
      when :mkv
        warn "MKV support not implemented"
        return nil
      when :ogg
        read_ogg_tags(file_path)
      else
        warn "Unsupported file format: #{media_type}"
        return nil
      end
    end

    # Write playtag tag to file
    def self.write(file_path, tag_value)
      unless tag_value.start_with?("#{Playtag::VERSION};")
        tag_value = "#{Playtag::VERSION}; #{tag_value}"
      end

      # Detect file type using MIME type
      media_type = detect_media_type(file_path)
      
      case media_type
      when :mp4
        write_mp4_tags(file_path, tag_value)
      when :mp3
        write_mp3_tags(file_path, tag_value)
      when :flac
        write_flac_tags(file_path, tag_value)
      when :mkv
        warn "MKV support not implemented"
        return false
      when :ogg
        write_ogg_tags(file_path, tag_value)
      else
        warn "Unsupported file format: #{media_type}"
        return false
      end
    end
    
    # Detect media type using MIME detection and file magic
    def self.detect_media_type(file_path)
      # First try using MIME::Types
      mime_type = MIME::Types.type_for(file_path).first
      
      if mime_type
        mime_str = mime_type.to_s
        debug "MIME type detected: #{mime_str}"
        
        return :mp4 if mime_str.match?(/mp4|m4a|m4v/)
        return :mp3 if mime_str.match?(/mpeg|mp3/)
        return :flac if mime_str.match?(/flac/)
        return :ogg if mime_str.match?(/ogg/)
        return :mkv if mime_str.match?(/matroska|mkv/)
      end
      
      # If MIME::Types didn't provide a useful result, try using the file command
      if system("which file > /dev/null 2>&1")
        file_output = `file --mime-type -b "#{file_path}"`.strip
        debug "file command detected: #{file_output}"
        
        return :mp4 if file_output.match?(/mp4|quicktime|m4a/)
        return :mp3 if file_output.match?(/mpeg|mp3/)
        return :flac if file_output.match?(/flac/)
        return :ogg if file_output.match?(/ogg/)
        return :mkv if file_output.match?(/matroska/)
      end
      
      # If we got here, we couldn't detect the type
      warn "Could not detect media type for: #{file_path}"
      :unknown
    end

    # Parse playtag tag string to options hash
    # Returns a hash of string options
    def self.parse_tag_to_options(tag_str)
      return {} if tag_str.nil? || tag_str.empty?

      # Remove version prefix
      tag_str = tag_str.sub(/^v\d+;\s*/, '')

      # Parse options
      options = {}
      tag_str.split(';').each do |opt|
        opt = opt.strip
        next if opt.empty?

        parts = opt.split('=', 2)
        if parts.size == 2
          key = parts[0].strip
          value = parts[1].strip
          options[key] = value
        else
          # Handle boolean options
          options[opt] = true
        end
      end

      options
    end

    # Convert options hash back to tag string
    def self.options_to_tag(options)
      return "#{Playtag::VERSION}; " if options.nil? || options.empty?

      parts = ["#{Playtag::VERSION}"]

      options.each do |key, value|
        if value == true
          parts << key
        else
          parts << "#{key}=#{value}"
        end
      end

      parts.join("; ")
    end

    # Parse time string to seconds
    def self.parse_time(time_str)
      if time_str =~ /^\d+$/
        # Simple seconds
        return time_str.to_f
      elsif time_str =~ /^(\d+):(\d+)(?::(\d+))?(?:\.(\d+))?$/
        # HH:MM:SS.mmm format
        hours = $1.to_i
        minutes = $2.to_i
        seconds = $3 ? $3.to_i : 0
        milliseconds = $4 ? $4.to_i : 0

        return hours * 3600 + minutes * 60 + seconds + (milliseconds / 1000.0)
      end

      # Invalid format
      nil
    end

    private

    # Read tags from MP4 files
    # @param file_path [String] Path to the MP4 file
    # @return [String, nil] The playtag value or nil if not found
    def self.read_mp4_tags(file_path)
      debug "Reading MP4 tags from #{file_path}"
      
      TagLib::MP4::File.open(file_path) do |file|
        unless file.tag
          debug "No MP4 tag found"
          return nil
        end

        tag = file.tag
        playtag_value = nil

        # Try different known method names for accessing all items
        # Note: item_map is a TagLib::MP4 API method that may not be recognized by static analyzers
        if tag.respond_to?(:item_map)
          if debug?
            debug "Trying to access tags via item_map..."
            # item_map is part of the TagLib::MP4 API
            tag.item_map.each_pair do |key, value|
              puts "  [#{key.inspect}, #{value.inspect}]"
            end
          end

          # Use has_key? method instead of key? for better compatibility
          # item_map is part of the TagLib::MP4 API
          if tag.item_map.has_key?(PLAYTAG_KEY) || tag.item_map.include?(PLAYTAG_KEY)
            item = tag.item_map[PLAYTAG_KEY]
            # to_string_list is part of the TagLib::MP4 API
            if item.respond_to?(:to_string_list)
              playtag_value = item.to_string_list.first.to_s
            else
              playtag_value = item.to_s
            end
          end
        end

        if playtag_value
          debug "Found playtag: #{playtag_value}"
          return playtag_value
        else
          debug "No playtag found via TagLib"
          return nil
        end
      end
    end

    # Write tags to MP4 files
    # @param file_path [String] Path to the MP4 file
    # @param tag_value [String] The playtag value to write
    # @return [Boolean] True if successful, false otherwise
    def self.write_mp4_tags(file_path, tag_value)
      debug "Writing MP4 tag to #{file_path}"
      
      TagLib::MP4::File.open(file_path) do |file|
        unless file.tag
          debug "No MP4 tag found"
          return false
        end

        tag = file.tag
        
        # List all available debug methods if debug is enabled
        # Unused variable, but keeping as a comment for future reference
        # debug_methods = tag.methods.sort.select { |m| m.to_s =~ /debug/ } if debug?
        
        # Try different known method names for removing existing items
        # remove_item is part of the TagLib::MP4 API
        if tag.respond_to?(:remove_item)
          debug "Removing existing playtag via remove_item..."
          tag.remove_item(PLAYTAG_KEY)
        end
        
        # Create a new item with the tag value
        # from_string_list is part of the TagLib::MP4 API
        debug "Creating new playtag item: #{tag_value.inspect}"
        item = TagLib::MP4::Item.from_string_list([tag_value])
        
        # Set the item in the tag
        # item_map is part of the TagLib::MP4 API
        if tag.respond_to?(:item_map)
          debug "Setting playtag via item_map..."
          tag.item_map[PLAYTAG_KEY] = item
        end
        
        # Save the file
        debug "Saving MP4 file..."
        file.save
      end
      
      true
    rescue => e
      debug "Error writing MP4 tag: #{e.message}"
      debug e.backtrace.join("\n")
      false
    end

    # Read tags from MP3 files
    # @param file_path [String] Path to the MP3 file
    # @return [String, nil] The playtag value or nil if not found
    def self.read_mp3_tags(file_path)
      debug "Reading MP3 tags from #{file_path}"
      
      TagLib::MPEG::File.open(file_path) do |file|
        # id3v2_tag is part of the TagLib::MPEG API
        unless file.id3v2_tag
          debug "No ID3v2 tag found"
          return nil
        end

        # id3v2_tag is part of the TagLib::MPEG API
        tag = file.id3v2_tag
        playtag_value = nil
        
        # frame_list is part of the TagLib::ID3v2 API
        if tag.frame_list("TXXX").any? do |frame|
          # field_list is part of the TagLib::ID3v2 API
          frame.field_list.size > 1 && frame.field_list[0].to_s == PLAYTAG_KEY
        end
          # Find the frame with our key
          # field_list is part of the TagLib::ID3v2 API
          frame = tag.frame_list("TXXX").find { |f| f.field_list[0].to_s == PLAYTAG_KEY }
          playtag_value = frame.field_list[1].to_s
        end
        
        if playtag_value
          debug "Found playtag: #{playtag_value}"
          return playtag_value
        else
          debug "No playtag found via TagLib"
          return nil
        end
      end
    end

    # Write tags to MP3 files
    # @param file_path [String] Path to the MP3 file
    # @param tag_value [String] The playtag value to write
    # @return [Boolean] True if successful, false otherwise
    def self.write_mp3_tags(file_path, tag_value)
      debug "Writing MP3 tag to #{file_path}"
      
      TagLib::MPEG::File.open(file_path) do |file|
        # id3v2_tag is part of the TagLib::MPEG API
        unless file.id3v2_tag
          debug "No ID3v2 tag found"
          return false
        end
        
        # id3v2_tag is part of the TagLib::MPEG API
        tag = file.id3v2_tag
        
        # Remove any existing frames with our key
        # frame_list is part of the TagLib::ID3v2 API
        tag.frame_list("TXXX").each do |frame|
          # field_list is part of the TagLib::ID3v2 API
          if frame.field_list.size > 1 && frame.field_list[0].to_s == PLAYTAG_KEY
            # remove_frame is part of the TagLib::ID3v2 API
            tag.remove_frame(frame)
          end
        end
        
        # Create a new frame with the tag value
        # UserTextIdentificationFrame is part of the TagLib::ID3v2 API
        debug "Creating new playtag frame: #{tag_value.inspect}"
        frame = TagLib::ID3v2::UserTextIdentificationFrame.new
        frame.field_list = [PLAYTAG_KEY, tag_value]
        # add_frame is part of the TagLib::ID3v2 API
        tag.add_frame(frame)
        
        # Save the file
        debug "Saving MP3 file..."
        file.save
      end
      
      true
    rescue => e
      debug "Error writing MP3 tag: #{e.message}"
      debug e.backtrace.join("\n")
      false
    end

    # Read tags from FLAC files
    # @param file_path [String] Path to the FLAC file
    # @return [String, nil] The playtag value or nil if not found
    def self.read_flac_tags(file_path)
      debug "Reading FLAC tags from #{file_path}"
      
      TagLib::FLAC::File.open(file_path) do |file|
        # xiph_comment is part of the TagLib::FLAC API
        unless file.xiph_comment
          debug "No XiphComment tag found"
          return nil
        end

        # xiph_comment is part of the TagLib::FLAC API
        tag = file.xiph_comment
        playtag_value = nil
        
        # Handle differently depending on API version
        # field_list_map is part of the TagLib::Ogg API
        if tag.respond_to?(:field_list_map) && tag.field_list_map.has_key?(PLAYTAG_KEY)
          playtag_value = tag.field_list_map[PLAYTAG_KEY].first
        elsif tag.respond_to?(:contains) && tag.contains(PLAYTAG_KEY)
          playtag_value = tag.field(PLAYTAG_KEY).first
        end
        
        if playtag_value
          debug "Found playtag: #{playtag_value}"
          return playtag_value
        else
          debug "No playtag found via TagLib"
          return nil
        end
      end
    end

    # Write tags to FLAC files
    # @param file_path [String] Path to the FLAC file
    # @param tag_value [String] The playtag value to write
    # @return [Boolean] True if successful, false otherwise
    def self.write_flac_tags(file_path, tag_value)
      debug "Writing FLAC tag to #{file_path}"
      
      TagLib::FLAC::File.open(file_path) do |file|
        # xiph_comment is part of the TagLib::FLAC API
        unless file.xiph_comment
          debug "No XiphComment tag found"
          return false
        end
        
        tag = file.xiph_comment
        
        # Remove any existing fields with our key
        debug "Removing existing playtag..."
        tag.remove_fields(PLAYTAG_KEY)
        
        # Add the new field
        debug "Adding new playtag: #{tag_value.inspect}"
        tag.add_field(PLAYTAG_KEY, tag_value)
        
        # Save the file
        debug "Saving FLAC file..."
        file.save
      end
      
      true
    rescue => e
      debug "Error writing FLAC tag: #{e.message}"
      debug e.backtrace.join("\n")
      false
    end

    # Read tags from OGG files
    # @param file_path [String] Path to the OGG file
    # @return [String, nil] The playtag value or nil if not found
    def self.read_ogg_tags(file_path)
      debug "Reading OGG tags from #{file_path}"
      
      TagLib::Ogg::Vorbis::File.open(file_path) do |file|
        # xiph_comment is part of the TagLib::Ogg::Vorbis API
        unless file.xiph_comment
          debug "No XiphComment tag found"
          return nil
        end

        # xiph_comment is part of the TagLib::Ogg::Vorbis API
        tag = file.xiph_comment
        playtag_value = nil
        
        # Handle differently depending on API version
        # field_list_map is part of the TagLib::Ogg API
        if tag.respond_to?(:field_list_map) && tag.field_list_map.has_key?(PLAYTAG_KEY)
          playtag_value = tag.field_list_map[PLAYTAG_KEY].first
        elsif tag.respond_to?(:contains) && tag.contains(PLAYTAG_KEY)
          playtag_value = tag.field(PLAYTAG_KEY).first
        end
        
        if playtag_value
          debug "Found playtag: #{playtag_value}"
          return playtag_value
        else
          debug "No playtag found via TagLib"
          return nil
        end
      end
    end

    # Write tags to OGG files
    # @param file_path [String] Path to the OGG file
    # @param tag_value [String] The playtag value to write
    # @return [Boolean] True if successful, false otherwise
    def self.write_ogg_tags(file_path, tag_value)
      debug "Writing OGG tag to #{file_path}"
      
      TagLib::Ogg::Vorbis::File.open(file_path) do |file|
        # xiph_comment is part of the TagLib::Ogg::Vorbis API
        unless file.xiph_comment
          debug "No XiphComment tag found"
          return false
        end
        
        tag = file.xiph_comment
        
        # Remove any existing fields with our key
        debug "Removing existing playtag..."
        tag.remove_fields(PLAYTAG_KEY)
        
        # Add the new field
        debug "Adding new playtag: #{tag_value.inspect}"
        tag.add_field(PLAYTAG_KEY, tag_value)
        
        # Save the file
        debug "Saving OGG file..."
        file.save
      end
      
      true
    rescue => e
      debug "Error writing OGG tag: #{e.message}"
      debug e.backtrace.join("\n")
      false
    end

    # Create a backup of the file
    def self.backup_file(file_path)
      backup_path = "#{file_path}.bak"

      # Don't overwrite existing backups
      return if File.exist?(backup_path)

      begin
        FileUtils.cp(file_path, backup_path)
        debug "Created backup: #{backup_path}"
      rescue => e
        warn "Warning: Failed to create backup: #{e.message}"
      end
    end

    # Utility methods for output
    def self.debug?
      ENV['PLAYTAG_DEBUG'] == '1'
    end

    def self.debug(message)
      $stderr.puts message if debug?
    end

    def self.warn(message)
      $stderr.puts "playtag: #{message}"
    end
  end
end
