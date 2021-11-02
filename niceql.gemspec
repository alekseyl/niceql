# coding: utf-8
lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "niceql/version"

Gem::Specification.new do |spec|
  spec.name          = "niceql"
  spec.version       = Niceql::VERSION
  spec.authors       = ["alekseyl"]
  spec.email         = ["leshchuk@gmail.com"]

  spec.summary       = %q{This is a simple and nice gem for SQL prettifying and formatting. Niceql splits, indent and colorize SQL query and PG errors if any. }
  spec.description   = %q{This is a simple and nice gem for SQL prettifying and formatting. Niceql splits, indent and colorize SQL query and PG errors if any. Could be used as a standalone gem without any dependencies. Seamless ActiveRecord integration. }
  spec.homepage      = "https://github.com/alekseyl/niceql"
  spec.license       = "MIT"

  # Prevent pushing this gem to RubyGems.org. To allow pushes either set the 'allowed_push_host'
  # to allow pushing to a single host or delete this section to allow pushing to any host.
  if spec.respond_to?(:metadata)
    spec.metadata["allowed_push_host"] = "https://rubygems.org"
  else
    raise "RubyGems 2.0 or newer is required to protect against " \
      "public gem pushes."
  end

  spec.files         = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.required_ruby_version = '>= 2.4'
  spec.add_development_dependency "activerecord", ">= 6.1"

  spec.add_development_dependency "bundler", ">= 1"
  spec.add_development_dependency "rake", ">= 12.3.3"
  spec.add_development_dependency "minitest", "~> 5.0"

  spec.add_development_dependency "differ"
  spec.add_development_dependency "pry-byebug"
  spec.add_development_dependency "benchmark-ips"
  spec.add_development_dependency 'sqlite3'
end
