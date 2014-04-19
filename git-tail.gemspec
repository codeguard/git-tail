# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'git/tail/version'

Gem::Specification.new do |spec|
  spec.name          = "git-tail"
  spec.version       = Git::Tail::VERSION
  spec.authors       = ["CodeGuard"]
  spec.email         = ["committers@codeguard.com"]
  spec.summary       = %q{Shrink Git repositories by truncating history}
  spec.description   = <<-END
    `git tail` is a destructive, usually undesirable command for making
    your Git repo smaller. Give it an age (specific date or relative
    time ago) and it will erase all commit history and objects prior to that
    date, leaving a smaller and fresher .git directory in its wake. Older
    tags and remote branches are deleted without remorse. This is the
    nuclear option for repo optimization: useful if you're using Git as a
    backup system, but causing too many mutations for distributed
    development.
    END
  spec.homepage      = "https://github.com/codeguard/git-tail"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.5"
  spec.add_development_dependency "rake"

  spec.add_runtime_dependency "trollop", "~> 2.0"
  spec.add_runtime_dependency "rainbow", "~> 1.99"
  spec.add_runtime_dependency "childprocess", "~> 0.5.2"
end
