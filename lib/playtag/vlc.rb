# frozen_string_literal: true

require_relative 'logger'

module Playtag
  class VLC
    extend Playtag::Logger

    def self.play(file_path, vlc_args = [])
      # Check if file exists
      unless File.exist?(file_path)
        error "File not found: #{file_path}"
        return false
      end

      # Find VLC executable
      vlc_exe = find_vlc_executable
      unless vlc_exe
        error 'VLC executable not found'
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
        if opts['vol'] && (opts['vol'] =~ /([+-]?\d+(?:\.\d+)?)\s*dB/)
          db_value = ::Regexp.last_match(1).to_f
          command << "--gain=#{db_value / 20.0}"
        end

        # Handle time ranges
        if opts['t']
          # Time pattern for HH:MM:SS.ss or SS.ss format
          time_pattern = '\d+:?\d*:?\d*(?:\.\d+)?'

          # Parse time range (start-stop, start-, -stop)
          case opts['t']
          when /^(#{time_pattern})-(#{time_pattern})$/
            start_time = ::Regexp.last_match(1)&.then { |match| Tag.parse_time(match) }
            stop_time = ::Regexp.last_match(2)&.then { |match| Tag.parse_time(match) }

            command << "--start-time=#{start_time.to_i}" if start_time
            command << "--stop-time=#{stop_time.to_i}" if stop_time
          when /^(#{time_pattern})-?$/
            start_time = ::Regexp.last_match(1)&.then { |match| Tag.parse_time(match) }
            command << "--start-time=#{start_time.to_i}" if start_time
          when /^-(#{time_pattern})$/
            stop_time = ::Regexp.last_match(1)&.then { |match| Tag.parse_time(match) }
            command << "--stop-time=#{stop_time.to_i}" if stop_time
          end
        end

        # Handle audio-video sync
        if opts['av-delay'] && (opts['av-delay'] =~ /([+-]?\d+(?:\.\d+)?)/)
          delay_ms = ::Regexp.last_match(1).to_f * 1000
          command << "--audio-desync=#{delay_ms.to_i}"
        end

        # Handle aspect ratio
        command << "--aspect-ratio=#{opts['aspect-ratio']}" if opts['aspect-ratio']

        # Handle mirroring (horizontal flip)
        command << '--video-filter=transform{type=hflip}' if opts['mirror']
      end

      # Add the file to play
      command << file_path

      # Run VLC
      system(*command)
    end

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
