module Playtag
  class VLC
    def self.play(file_path, vlc_args = [])
      # Check if file exists
      unless File.exist?(file_path)
        Tag.warn "Error: File not found: #{file_path}"
        return false
      end

      # Find VLC executable
      vlc_exe = find_vlc_executable
      unless vlc_exe
        Tag.warn "Error: VLC executable not found"
        return false
      end

      # Read playtag
      tag = Tag.read(file_path)
      command = [vlc_exe]

      # Add VLC arguments
      command.concat(vlc_args)

      # If tag exists, parse it and add VLC-specific options
      if tag && !tag.empty?
        opts = Tag.parse_tag_to_options(tag)

        # Handle volume adjustment
        if opts['vol']
          if opts['vol'] =~ /([+-]?\d+(?:\.\d+)?)\s*dB/
            db_value = $1.to_f
            command << "--gain=#{db_value / 20.0}"
          end
        end

        # Handle time ranges
        if opts['t']
          # Parse time range (start-stop, start-, -stop)
          if opts['t'] =~ /^(\d+:?\d*:?\d*(?:\.\d+)?)-(\d+:?\d*:?\d*(?:\.\d+)?)$/
            start_time = Tag.parse_time($1)
            stop_time = Tag.parse_time($2)

            command << "--start-time=#{start_time.to_i}" if start_time
            command << "--stop-time=#{stop_time.to_i}" if stop_time
          elsif opts['t'] =~ /^(\d+:?\d*:?\d*(?:\.\d+)?)-$/
            start_time = Tag.parse_time($1)
            command << "--start-time=#{start_time.to_i}" if start_time
          elsif opts['t'] =~ /^-(\d+:?\d*:?\d*(?:\.\d+)?)$/
            stop_time = Tag.parse_time($1)
            command << "--stop-time=#{stop_time.to_i}" if stop_time
          elsif opts['t'] =~ /^(\d+:?\d*:?\d*(?:\.\d+)?)$/
            start_time = Tag.parse_time($1)
            command << "--start-time=#{start_time.to_i}" if start_time
          end
        end

        # Handle audio-video sync
        if opts['av-delay']
          if opts['av-delay'] =~ /([+-]?\d+(?:\.\d+)?)/
            delay_ms = $1.to_f * 1000
            command << "--audio-desync=#{delay_ms.to_i}"
          end
        end

        # Handle aspect ratio
        if opts['aspect-ratio']
          command << "--aspect-ratio=#{opts['aspect-ratio']}"
        end

        # Handle mirroring (horizontal flip)
        if opts['mirror']
          command << "--video-filter=transform{type=hflip}"
        end
      end

      # Add the file to play
      command << file_path

      # Run VLC
      system(*command)
    end

    private

    def self.find_vlc_executable
      # Check common locations
      vlc_paths = [
        'vlc',
        '/usr/bin/vlc',
        '/usr/local/bin/vlc',
        '/Applications/VLC.app/Contents/MacOS/VLC',
        'C:\\Program Files\\VideoLAN\\VLC\\vlc.exe',
        'C:\\Program Files (x86)\\VideoLAN\\VLC\\vlc.exe'
      ]

      vlc_paths.each do |path|
        return path if system("which #{path} > /dev/null 2>&1")
      end

      nil
    end
  end
end
