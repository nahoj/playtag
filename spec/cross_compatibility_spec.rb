# frozen_string_literal: true

require 'spec_helper'
require 'fileutils'

RSpec.describe 'Playtag cross-compatibility with playtag-python', type: :aruba do
  let(:ruby_playtag_script) { File.expand_path('../../bin/playtag', __FILE__) }
  let(:python_playtag_script) { File.expand_path('../playtag-python', __FILE__) }

  # Ensure playtag-python is executable
  before(:all) do
    python_script_path = File.expand_path('../playtag-python', __FILE__)
    FileUtils.chmod('+x', python_script_path) if File.exist?(python_script_path)
  end

  shared_examples 'cross-compatibility tests' do |file_name, file_type|
    let(:test_file) { file_name }
    # Use a distinct name for the copied file in the Aruba workspace
    let(:copied_test_file) { "#{file_type.downcase}_test_file#{File.extname(file_name)}" }

    before(:each) do
      # Copy the fixture file to a unique name in the Aruba workspace
      copy "%/#{test_file}", copied_test_file
      # Clear any existing playtag from the copied file before running the test
      run_command_and_stop("#{ruby_playtag_script} clear #{copied_test_file}")
      expect(last_command_started).to be_successfully_executed, "Playtag clear command failed in before(:each) for #{copied_test_file}: #{last_command_started.output}"
    end

    context "for #{file_type} files (#{file_name})" do
      it 'Ruby can read a tag written by playtag-python' do
        # Write a single parameter using playtag-python
        run_command_and_stop("#{python_playtag_script} set t=10-20 #{copied_test_file}")
        expect(last_command_started).to be_successfully_executed, "playtag-python set failed with: #{last_command_started.output}"

        # Read entire Playtag tag using Ruby playtag
        run_command_and_stop("#{ruby_playtag_script} read #{copied_test_file}")
        expect(last_command_started).to be_successfully_executed, "Ruby playtag read failed with: #{last_command_started.output}"
        expect(last_command_started.stdout.strip).to eq('v1; t=10-20')
      end

      it 'playtag-python can read a tag written by Ruby playtag' do
        # Write a full tag string using Ruby playtag
        run_command_and_stop("#{ruby_playtag_script} write 'v1; t=10-20' #{copied_test_file}")
        expect(last_command_started).to be_successfully_executed, "Ruby playtag write failed with: #{last_command_started.output}"

        # Verify Ruby can read its own written tag immediately
        run_command_and_stop("#{ruby_playtag_script} read #{copied_test_file}")
        expect(last_command_started).to be_successfully_executed, "Ruby playtag read (self-check) failed: #{last_command_started.output}"
        expect(last_command_started.stdout.strip).to eq('v1; t=10-20'), "Ruby self-read check failed. Expected: 'v1; t=10-20', Got: '#{last_command_started.stdout.strip}'"

        # Read entire Playtag tag using playtag-python
        run_command_and_stop("#{python_playtag_script} get t #{copied_test_file}")
        expect(last_command_started).to be_successfully_executed, "playtag-python get failed with: #{last_command_started.output}"
        expect(last_command_started.stdout.strip).to eq('10-20')
      end
    end
  end

  # Define which files to test against
  describe 'FLAC cross-compatibility' do
    include_examples 'cross-compatibility tests', 'f.flac', 'FLAC'
  end

  describe 'MKV cross-compatibility' do
    include_examples 'cross-compatibility tests', 'k.mkv', 'MKV'
  end

  describe 'MP3 cross-compatibility' do
    include_examples 'cross-compatibility tests', 'o.mp3', 'MP3'
  end

  describe 'MP4 cross-compatibility' do
    include_examples 'cross-compatibility tests', 'l.mp4', 'MP4'
  end

  describe 'OGG cross-compatibility' do
    include_examples 'cross-compatibility tests', 'r.ogg', 'OGG'
  end
end
