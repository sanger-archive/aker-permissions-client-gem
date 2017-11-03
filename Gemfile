source 'https://rubygems.org'

# Specify your gem's dependencies in aker_stamp_client.gemspec
gemspec

# Force git gems to use secure HTTPS
git_source(:github) do |repo_name|
  repo_name = "#{repo_name}/#{repo_name}" unless repo_name.include?("/")
  "https://github.com/#{repo_name}.git"
end

gem 'json_api_client', github: 'sanger/json_api_client'
