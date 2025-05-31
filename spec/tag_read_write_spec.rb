# frozen_string_literal: true

require 'spec_helper'
require 'fileutils'

RSpec.describe 'Playtag tag reading and writing', type: :aruba do
  # Define the path to the playtag script
  let(:playtag_script) { File.expand_path('../../bin/playtag', __FILE__) }
  
  # Shared examples for tag reading and writing tests
  # This is similar to @ParameterizedTest in Java
  shared_examples 'tag operations' do |file_name|
    before(:each) do
      # Copy our test file from fixtures to the Aruba working directory
      copy "%/#{file_name}", file_name
    end

    it "can write a tag to #{file_name} and read it back" do
      # Write a tag to the file
      tag_value = 'v1; vol=+3dB; t=10-20'
      run_command_and_stop("#{playtag_script} write \"#{tag_value}\" #{file_name}")

      # Check that the write command succeeded
      expect(last_command_started).to be_successfully_executed

      # Now read the tag back
      run_command_and_stop("#{playtag_script} read #{file_name}")

      # Check that the read command succeeded
      expect(last_command_started).to be_successfully_executed

      # Check that the output contains the tag we wrote
      expect(last_command_started.stdout.strip).to eq(tag_value)
    end

    it "can update an existing tag in #{file_name}" do
      # First write an initial tag
      initial_tag = 'v1; vol=+3dB'
      run_command_and_stop("#{playtag_script} write \"#{initial_tag}\" #{file_name}")
      expect(last_command_started).to be_successfully_executed

      # Now update the tag
      updated_tag = 'v1; vol=+3dB; t=5-15'
      run_command_and_stop("#{playtag_script} write \"#{updated_tag}\" #{file_name}")
      expect(last_command_started).to be_successfully_executed

      # Read back the updated tag
      run_command_and_stop("#{playtag_script} read #{file_name}")
      expect(last_command_started).to be_successfully_executed

      # Check that the output contains the updated tag
      expect(last_command_started.stdout.strip).to eq(updated_tag)
    end
  end

  # Run the same tests for each file type
  describe 'with FLAC file' do
    include_examples 'tag operations', 'f.flac'
  end

  describe 'with MKV file' do
    include_examples 'tag operations', 'k.mkv'
  end

  describe 'with MP3 file' do
    include_examples 'tag operations', 'o.mp3'
  end

  describe 'with MP4 file' do
    include_examples 'tag operations', 'l.mp4'
  end

  describe 'with OGG file' do
    include_examples 'tag operations', 'r.ogg'
  end

  describe 'with WebM file' do
    include_examples 'tag operations', 'w.webm'
  end
end
