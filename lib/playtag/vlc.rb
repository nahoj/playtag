# frozen_string_literal: true

require_relative 'logger'

module Playtag
  class VLC
    include Playtag::Logger

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
          # Parse time range (start-stop, start-, -stop)
          case opts['t']
          when /^(\d+:?\d*:?\d*(?:\.\d+)?)-(\d+:?\d*:?\d*(?:\.\d+)?)$/
            start_time = Tag.parse_time(::Regexp.last_match(1))
            stop_time = Tag.parse_time(::Regexp.last_match(2))

            command << "--start-time=#{start_time.to_i}" if start_time
            command << "--stop-time=#{stop_time.to_i}" if stop_time
          when /^(\d+:?\d*:?\d*(?:\.\d+)?)-$/
            start_time = Tag.parse_time(::Regexp.last_match(1))
            command << "--start-time=#{start_time.to_i}" if start_time
          when /^-(\d+:?\d*:?\d*(?:\.\d+)?)$/
            stop_time = Tag.parse_time(::Regexp.last_match(1))
            command << "--stop-time=#{stop_time.to_i}" if stop_time
          when /^(\d+:?\d*:?\d*(?:\.\d+)?)$/
            start_time = Tag.parse_time(::Regexp.last_match(1))
            command << "--start-time=#{start_time.to_i}" if start_time
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
