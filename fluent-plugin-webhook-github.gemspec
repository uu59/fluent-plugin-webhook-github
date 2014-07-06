# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

Gem::Specification.new do |spec|
  spec.name          = "fluent-plugin-webhook-github"
  spec.version       = File.read(File.expand_path('../VERSION', __FILE__))
  spec.authors       = ["uu59"]
  spec.email         = ["k@uu59.org"]
  spec.summary       = %q{fluentd input plugin for receive GitHub webhook}
  spec.description   = %q{fluentd input plugin for receive GitHub webhook}
  spec.homepage      = ""
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_runtime_dependency "fluentd", "~> 0"
  spec.add_development_dependency "bundler", "~> 1.6"
  spec.add_development_dependency "rake"
end
