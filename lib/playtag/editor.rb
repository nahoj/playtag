module Playtag
  class Editor
    def self.edit(file_path)
      # Check if file exists
      unless File.exist?(file_path)
        Tag.warn "Error: File not found: #{file_path}"
        return false
      end

      # Read current tag
      current_tag = Tag.read(file_path)
      init_text = current_tag || "#{Playtag::VERSION}; "

      # Use readline for editing
      Readline.pre_input_hook = -> { Readline.insert_text(init_text) }
      begin
        new_tag = Readline.readline('Edit tag: ', true)
        Readline.pre_input_hook = nil

        if new_tag.empty?
          Tag.warn "Empty line; deleting tag instead."
          # Delete tag logic depends on file type - we'll just pass an empty string
          return Tag.write(file_path, "")
        else
          return Tag.write(file_path, new_tag)
        end
      rescue Interrupt
        puts "\nCancelled"
        return false
      ensure
        Readline.pre_input_hook = nil
      end
    end
  end
end
