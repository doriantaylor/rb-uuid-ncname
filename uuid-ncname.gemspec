
lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "uuid/ncname/version"

Gem::Specification.new do |spec|
  spec.name          = "uuid-ncname"
  spec.version       = UUID::NCName::VERSION
  spec.authors       = ["Dorian Taylor"]
  spec.email         = ["code@doriantaylor.com"]
  spec.license       = 'Apache-2.0'
  spec.homepage      = "https://github.com/doriantaylor/rb-uuid-ncname"
  spec.summary       = %q{Format a UUID as a valid NCName.}
  spec.description   = <<DESC
This module creates an isomorphic representation of a UUID which is
guaranteed to fit into the grammar of the XML NCName construct, which
also happens to exhibit (modulo case and hyphens) the same constraints
as identifiers in nearly all programming languages. Provides case
sensitive (Base64) and case-insensitive (Base32) variants.
DESC

  spec.files         = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  # we use named parameters
  spec.required_ruby_version = '>= 2.0'

  # surprisingly do not need this
  # spec.add_runtime_dependency 'uuidtools', '~> 2.1.5'
  spec.add_runtime_dependency 'base32',    '>= 0.3.2'
  spec.add_runtime_dependency 'base58',    '>= 0.2.3'

  spec.add_development_dependency 'bundler', '>= 2.2'
  spec.add_development_dependency 'rake',    '>= 13.0'
  spec.add_development_dependency 'rspec',   '>= 3.10'

  # only need it for testing, who knew
  # spec.add_development_dependency 'uuidtools', '~> 2.1.5'
  # actually don't even need it for that
end
