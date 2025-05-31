# frozen_string_literal: true

require 'optparse'
require_relative 'logger'

module Playtag
  class CLI
    extend Playtag::Logger

    def self.run(args)
      # Parse command-line options
      option_parser = OptionParser.new do |opts|
        opts.banner = 'Usage: playtag COMMAND [options] [file]'
        opts.separator ''
        opts.separator 'Commands:'
        opts.separator '  read FILE                   Read playtag from FILE'
        opts.separator '  write TAG FILE              Write TAG to FILE'
        opts.separator '  clear FILE                  Clear playtag tag from FILE'
        opts.separator '  edit FILE                   Edit playtag for FILE interactively'
        opts.separator '  vlc [VLC_ARGS] FILE         Play FILE with VLC using playtag parameters'
        opts.separator ''
        opts.separator 'Options:'

        opts.on('-d', '--debug', 'Enable debug output') do
          ENV['PLAYTAG_DEBUG'] = '1'
          update_log_level
        end

        opts.on('-b', '--backup', 'Create backup files before modifying') do
          ENV['PLAYTAG_BACKUP'] = '1'
        end

        opts.on('-h', '--help', 'Show this help message') do
          puts opts
          exit
        end
      end

      begin
        option_parser.parse!(args)

        # Process commands
        command = args.shift
        unless command
          puts option_parser
          exit 1
        end

        case command
        when 'read'
          file_path = args.shift
          unless file_path
            error 'Missing file argument'
            exit 1
          end

          # Temporarily store original debug setting
          original_debug = ENV['PLAYTAG_DEBUG']
          # Disable debug output for read command unless explicitly enabled with -d
          ENV['PLAYTAG_DEBUG'] = nil unless original_debug == '1'
          update_log_level
          
          tag = Tag.read(file_path)
          
          # Restore original debug setting
          ENV['PLAYTAG_DEBUG'] = original_debug
          update_log_level
          
          if tag
            puts tag
          else
            # Tag.read already logs a warning if no tag is found
            exit 1
          end

        when 'write'
          tag_value = args.shift
          file_path = args.shift
          unless file_path && tag_value
            error 'Missing arguments. Usage: playtag write TAG FILE'
            exit 1
          end

          success = Tag.write(file_path, tag_value)
          exit(success ? 0 : 1)

        when 'clear'
          file_path = args.shift
          unless file_path
            error 'Missing file argument. Usage: playtag clear FILE'
            exit 1
          end

          # Writing nil or an empty string to the tag handlers should remove the tag
          success = Tag.write(file_path, nil)
          exit(success ? 0 : 1)

        when 'edit'
          file_path = args.shift
          unless file_path
            error 'Missing file argument'
            exit 1
          end

          success = Editor.edit(file_path)
          exit(success ? 0 : 1)

        when 'vlc'
          # The last argument is the file, all others are VLC args
          file_path = args.pop
          unless file_path
            error 'Missing file argument'
            exit 1
          end

          success = VLC.play(file_path, args)
          exit(success ? 0 : 1)

        else
          error "Unknown command: #{command}"
          puts option_parser
          exit 1
        end
      rescue StandardError => e
        error "#{e.message}"
        exit 1
      end
    end
  end
end
