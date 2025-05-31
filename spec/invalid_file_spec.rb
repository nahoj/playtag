# frozen_string_literal: true

# require 'spec_helper'
#
# RSpec.describe 'Playtag with invalid files', type: :aruba do
#   # Define the path to the playtag script
#   let(:playtag_script) { File.expand_path('../../bin/playtag', __FILE__) }
#
#   # Setup test files before each test
#   before(:each) do
#     # Copy our invalid MP4 file from fixtures to the Aruba working directory
#     copy '%/phone_video.mp4', 'phone_video.mp4'
#   end
#
#   describe 'write command with invalid MP4' do
#     it 'fails to write tags to an invalid MP4 file' do
#       # Try to write a tag to the invalid file
#       run_command_and_stop("#{playtag_script} write \"v1; vol=+3dB\" phone_video.mp4",
#                            fail_on_error: false)
#
#       # Check that the command failed (non-zero exit status)
#       expect(last_command_started).to_not be_successfully_executed
#
#       # Check that error output contains appropriate message
#       puts 'last_command_started.stdout'
#       puts last_command_started.stdout
#       puts 'last_command_started.stderr'
#       puts last_command_started.stderr
#       expect(last_command_started.stderr).to include('Error') # FIXME
#     end
#   end
#
# end
