# frozen_string_literal: true

source 'https://rubygems.org'

# Core dependency for tag management
gem 'marcel', '~> 2.1'
gem 'nokogiri', '>= 1.18.9' # For XML parsing (MKV tags)
gem 'taglib-ruby', '~> 2.0'

# Optional development dependencies
group :development do
  gem 'rubocop', require: false # For code style checking
  gem 'json', '>= 2.19.9' # Rubocop dep, security patch
end

# Testing dependencies
group :test do
  gem 'aruba', '~> 2.1'
  gem 'rspec', '~> 3.12'
end
