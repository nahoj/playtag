# frozen_string_literal: true

require 'optparse'

module Playtag
  class CLI
    def self.run(args)
      # Parse command-line options
      option_parser = OptionParser.new do |opts|
        opts.banner = 'Usage: playtag COMMAND [options] [file]'
        opts.separator ''
        opts.separator 'Commands:'
        opts.separator '  read FILE                   Read playtag from FILE'
        opts.separator '  write FILE TAG              Write TAG to FILE'
        opts.separator '  edit FILE                   Edit playtag for FILE interactively'
        opts.separator '  vlc [VLC_ARGS] FILE         Play FILE with VLC using playtag parameters'
        opts.separator ''
        opts.separator 'Options:'

        opts.on('-d', '--debug', 'Enable debug output') do
          ENV['PLAYTAG_DEBUG'] = '1'
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
            puts 'Error: Missing file argument'
            exit 1
          end

          tag = Tag.read(file_path)
          if tag
            puts tag
          else
            exit 1
          end

        when 'write'
          file_path = args.shift
          tag_value = args.shift
          unless file_path && tag_value
            puts 'Error: Missing arguments. Usage: playtag write FILE TAG'
            exit 1
          end

          success = Tag.write(file_path, tag_value)
          exit(success ? 0 : 1)

        when 'edit'
          file_path = args.shift
          unless file_path
            puts 'Error: Missing file argument'
            exit 1
          end

          success = Editor.edit(file_path)
          exit(success ? 0 : 1)

        when 'vlc'
          # The last argument is the file, all others are VLC args
          file_path = args.pop
          unless file_path
            puts 'Error: Missing file argument'
            exit 1
          end

          success = VLC.play(file_path, args)
          exit(success ? 0 : 1)

        else
          puts "Unknown command: #{command}"
          puts option_parser
          exit 1
        end
      rescue StandardError => e
        puts "Error: #{e.message}"
        exit 1
      end
    end
  end
end
