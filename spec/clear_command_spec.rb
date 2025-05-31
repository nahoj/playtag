# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'The playtag clear command', type: :aruba do
  let(:playtag_script) { File.expand_path('../bin/playtag', __dir__) }
  let(:initial_tag) { 'v1; t=10-20; vol=+3dB; aspect-ratio=16:9' }

  shared_examples 'playtag clear command tests' do |file_fixture_name, file_type_description|
    let(:test_file) { file_fixture_name }

    before(:each) do
      # Copy the specific fixture file for this context
      copy "%/#{test_file}", test_file
      # Ensure the file has a known tag to start with
      run_command_and_stop("#{playtag_script} write \"#{initial_tag}\" #{test_file}")
      expect(last_command_started).to be_successfully_executed,
                                      "Failed to write initial tag to #{test_file}: #{last_command_started.output}"
    end

    it "clears an existing playtag tag from an #{file_type_description} file" do
      # Run the clear command
      run_command_and_stop("#{playtag_script} clear #{test_file}")
      expect(last_command_started).to be_successfully_executed,
                                      "playtag clear failed for #{test_file}: #{last_command_started.output}"

      # Verify the tag is gone by trying to read it
      run_command_and_stop("#{playtag_script} read #{test_file}", fail_on_error: false)
      # Reading a cleared tag should result in non-zero exit status
      expect(last_command_started).not_to be_successfully_executed
      # Logger will output WARN message to stderr
      expect(last_command_started.stderr).to include('INFO: No playtag tag found')
      # But no actual tag content should be in stdout
      expect(last_command_started.stdout.strip).to be_empty
    end

    it "handles clearing an #{file_type_description} file that has no playtag tag (succeeds silently)" do
      # First, clear the initial tag
      run_command_and_stop("#{playtag_script} clear #{test_file}")
      expect(last_command_started).to be_successfully_executed

      # Now, try to clear it again
      run_command_and_stop("#{playtag_script} clear #{test_file}")
      expect(last_command_started).to be_successfully_executed
      expect(last_command_started.stdout.strip).to be_empty # No output on success
    end
  end

  describe 'for FLAC files' do
    include_examples 'playtag clear command tests', 'f.flac', 'FLAC'
  end

  describe 'for MKV files' do
    include_examples 'playtag clear command tests', 'k.mkv', 'MKV'
  end

  describe 'for MP3 files' do
    include_examples 'playtag clear command tests', 'o.mp3', 'MP3'
  end

  describe 'for MP4 files' do
    include_examples 'playtag clear command tests', 'l.mp4', 'MP4'
  end

  describe 'for OGG files' do
    include_examples 'playtag clear command tests', 'r.ogg', 'OGG'
  end

  describe 'for WebM files' do
    include_examples 'playtag clear command tests', 'w.webm', 'WebM'
  end

  # General failure cases for the clear command
  describe 'failure cases' do
    it 'fails if no file is specified' do
      run_command_and_stop("#{playtag_script} clear", fail_on_error: false)
      expect(last_command_started).not_to be_successfully_executed
      expect(last_command_started.stderr).to include('ERROR: Missing file argument. Usage: playtag clear FILE')
    end

    it 'fails if the specified file does not exist' do
      run_command_and_stop("#{playtag_script} clear non_existent_file.mp4", fail_on_error: false)
      expect(last_command_started).not_to be_successfully_executed
      expect(last_command_started.stderr).to include('WARN: File not found: non_existent_file.mp4')
    end
  end
end
