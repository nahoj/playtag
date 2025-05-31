# frozen_string_literal: true

require 'fileutils'
require 'mime/types'
require 'optparse'
require 'readline'
require 'taglib'

# Require all component files
require_relative 'playtag/version'
require_relative 'playtag/logger'
require_relative 'playtag/tag'
require_relative 'playtag/editor'
require_relative 'playtag/vlc'
require_relative 'playtag/cli'
