require 'spec_helper'

RSpec.describe 'Playtag with invalid files', type: :aruba do
  # Define the path to the playtag script
  let(:playtag_script) { File.expand_path('../../bin/playtag', __FILE__) }
  
  # Setup test files before each test
  before(:each) do
    # Copy our invalid MP4 file from fixtures to the Aruba working directory
    copy '%/phone_video.mp4', 'phone_video.mp4'
  end

  describe 'write command with invalid MP4' do
    it 'fails to write tags to an invalid MP4 file' do
      # Try to write a tag to the invalid file
      run_command_and_stop("#{playtag_script} write phone_video.mp4 \"v1; vol=+3dB\"",
                           fail_on_error: false)

      # Check that the command failed (non-zero exit status)
      expect(last_command_started).to_not be_successfully_executed

      # Check that error output contains appropriate message
      puts 'last_command_started.stdout'
      puts last_command_started.stdout
      puts 'last_command_started.stderr'
      puts last_command_started.stderr
      expect(last_command_started.stderr).to include('Error') # FIXME
    end
  end

  # describe 'read command with invalid MP4' do
  #   it 'fails to read tags from an invalid MP4 file' do
  #     # Try to read tags from the invalid file
  #     run_command_and_stop("#{playtag_script} read phone_video.mp4")
  #
  #     # Check that the command failed (non-zero exit status)
  #     expect(last_command_started).to_not be_successfully_executed
  #
  #     # Check that error output contains appropriate message
  #     expect(last_command_started.stderr).to include('Error')
  #   end
  # end
  #
  # describe 'edit command with invalid MP4' do
  #   it 'fails to edit tags in an invalid MP4 file' do
  #     # Try to edit tags in the invalid file (with echo to simulate user input)
  #     run_command("echo \"v1; t=10-20\" | #{playtag_script} edit phone_video.mp4")
  #
  #     # Wait for the command to finish
  #     stop_all_commands
  #
  #     # Check that the command failed (non-zero exit status)
  #     expect(last_command_started).to_not be_successfully_executed
  #
  #     # Check that error output contains appropriate message
  #     expect(last_command_started.stderr).to include('Error')
  #   end
  # end
end
