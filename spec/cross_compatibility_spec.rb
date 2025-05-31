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

    before(:each) do
      # Copy test file from fixtures to Aruba's working directory
      copy "%/#{test_file}", test_file
    end

    context "for #{file_type} files (#{file_name})" do
      it 'Ruby can read a tag written by playtag-python' do
        # Write single parameter using playtag-python
        run_command_and_stop("#{python_playtag_script} set t=10-20 #{test_file}")
        expect(last_command_started).to be_successfully_executed, "playtag-python set failed with: #{last_command_started.output}"

        # Read entire Playtag tag using Ruby playtag
        run_command_and_stop("#{ruby_playtag_script} read #{test_file}")
        expect(last_command_started).to be_successfully_executed, "Ruby playtag read failed with: #{last_command_started.output}"
        expect(last_command_started.stdout.strip).to eq('v1; t=10-20')
      end

      it 'playtag-python can read a tag written by Ruby playtag' do
        # Write entire Playtag tag using Ruby playtag
        run_command_and_stop("#{ruby_playtag_script} write \"v1; vol=+3dB\" #{test_file}")
        expect(last_command_started).to be_successfully_executed, "Ruby playtag write failed with: #{last_command_started.output}"

        # Read single parameter using playtag-python
        run_command_and_stop("#{python_playtag_script} get vol #{test_file}")
        expect(last_command_started).to be_successfully_executed, "playtag-python get failed with: #{last_command_started.output}"
        expect(last_command_started.stdout.strip).to eq('+3dB')
      end
    end
  end

  # Define which files to test against
  describe 'MP4 cross-compatibility' do
    include_examples 'cross-compatibility tests', 'l.mp4', 'MP4'
  end

  describe 'MP3 cross-compatibility' do
    include_examples 'cross-compatibility tests', 'o.mp3', 'MP3'
  end

  describe 'OGG cross-compatibility' do
    include_examples 'cross-compatibility tests', 'r.ogg', 'OGG'
  end

  # Future: Add FLAC if test fixtures are available
  # describe 'FLAC cross-compatibility' do
  #   include_examples 'cross-compatibility tests', 'test.flac', 'FLAC'
  # end
end
