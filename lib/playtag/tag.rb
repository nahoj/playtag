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

    # Read tags from MP4 file
    def self.read_mp4_tags(file_path)
      begin
        TagLib::MP4::File.open(file_path) do |file|
          if file.tag.nil?
            warn "No MP4 tag found"
            return nil
          end

          tag = file.tag
          playtag_value = nil

          # Try different known method names for accessing all items
          if tag.respond_to?(:item_map)
            if debug?
              debug "Trying to access tags via item_map..."
              tag.item_map.each_pair do |key, value|
                puts "  [#{key.inspect}, #{value.inspect}]"
              end
            end

            # Use has_key? method instead of key? for better compatibility
            if tag.item_map.has_key?(PLAYTAG_KEY) || tag.item_map.include?(PLAYTAG_KEY)
              item = tag.item_map[PLAYTAG_KEY]
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
          end
        end

        return nil
      rescue => e
        warn "Error reading MP4 file: #{e.message}"
        return nil
      end
    end

    # Write tags to MP4 file
    def self.write_mp4_tags(file_path, tag_value)
      begin
        # Create a backup before modifying
        backup_file(file_path) if ENV['PLAYTAG_BACKUP'] == '1'

        success = false

        TagLib::MP4::File.open(file_path) do |file|
          if file.tag.nil?
            warn "Error: No MP4 tag found, cannot write"
            return false
          end

          tag = file.tag

          # Get available methods
          debug "Available methods on MP4::Tag for writing:"
          write_methods = tag.methods.grep(/set|add|item|remove/).sort
          debug_methods = write_methods if debug?

          # Try to use item_map or remove_item + add_item
          if tag.respond_to?(:remove_item) && tag.respond_to?(:item_map)
            debug "Trying remove_item and item_map..."
            begin
              # First remove the existing item if any
              tag.remove_item(PLAYTAG_KEY)

              # Create a proper MP4::Item object
              # The correct way to create a string item in MP4 format
              tag_array = [tag_value]  # Put the string in an array
              item = TagLib::MP4::Item.from_string_list(tag_array)

              # Now assign the properly created item
              tag.item_map[PLAYTAG_KEY] = item
              success = true
            rescue => e
              warn "Error with remove_item/item_map: #{e.message}"
            end
          end

          # Save if any method was successful
          if success
            if file.save
              debug "Successfully wrote playtag via TagLib: #{tag_value}"
              return true
            else
              warn "Failed to save file"
              success = false
            end
          end
        end

        return success
      rescue => e
        warn "Error writing to MP4 file: #{e.message}"
        return false
      end
    end

    # Read tags from MP3 file
    def self.read_mp3_tags(file_path)
      begin
        TagLib::MPEG::File.open(file_path) do |file|
          unless file.id3v2_tag
            warn "No ID3v2 tag found"
            return nil
          end

          # Look for TXXX frame with playtag
          tag = file.id3v2_tag
          frames = tag.frame_list("TXXX")

          playtag_frame = frames.find { |frame| frame.field_list.first == "PLAYTAG" }

          if playtag_frame
            playtag_value = playtag_frame.field_list.last
            debug "Found playtag: #{playtag_value}"
            return playtag_value
          else
            debug "No playtag found"
            return nil
          end
        end
      rescue => e
        warn "Error reading MP3 file: #{e.message}"
        return nil
      end
    end

    # Write tags to MP3 file
    def self.write_mp3_tags(file_path, tag_value)
      begin
        # Create a backup before modifying
        backup_file(file_path) if ENV['PLAYTAG_BACKUP'] == '1'

        TagLib::MPEG::File.open(file_path) do |file|
          tag = file.id3v2_tag(true)

          # Remove existing PLAYTAG frames
          frames = tag.frame_list("TXXX")
          frames.each do |frame|
            if frame.field_list.first == "PLAYTAG"
              tag.remove_frame(frame)
            end
          end

          # Add new PLAYTAG frame
          frame = TagLib::ID3v2::UserTextIdentificationFrame.new
          frame.description = "PLAYTAG"
          frame.text = tag_value
          tag.add_frame(frame)

          # Save the changes
          if file.save
            debug "Successfully wrote playtag: #{tag_value}"
            return true
          else
            warn "Failed to save file"
            return false
          end
        end
      rescue => e
        warn "Error writing to MP3 file: #{e.message}"
        return false
      end
    end

    # Read tags from FLAC file
    def self.read_flac_tags(file_path)
      begin
        TagLib::FLAC::File.open(file_path) do |file|
          unless file.xiph_comment
            warn "No Xiph Comment found"
            return nil
          end

          tag = file.xiph_comment

          if tag.contains?("PLAYTAG")
            playtag_value = tag.field_list_map["PLAYTAG"].first
            debug "Found playtag: #{playtag_value}"
            return playtag_value
          else
            debug "No playtag found"
            return nil
          end
        end
      rescue => e
        warn "Error reading FLAC file: #{e.message}"
        return nil
      end
    end

    # Write tags to FLAC file
    def self.write_flac_tags(file_path, tag_value)
      begin
        # Create a backup before modifying
        backup_file(file_path) if ENV['PLAYTAG_BACKUP'] == '1'

        TagLib::FLAC::File.open(file_path) do |file|
          tag = file.xiph_comment(true)

          # Set the playtag
          tag.add_field("PLAYTAG", tag_value, true)

          # Save the changes
          if file.save
            debug "Successfully wrote playtag: #{tag_value}"
            return true
          else
            warn "Failed to save file"
            return false
          end
        end
      rescue => e
        warn "Error writing to FLAC file: #{e.message}"
        return false
      end
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
