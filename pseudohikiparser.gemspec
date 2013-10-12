# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'pseudohiki/version'

Gem::Specification.new do |spec|
  spec.name          = "pseudohikiparser"
  spec.version       = PseudoHiki::VERSION
  spec.required_ruby_version = ">= 1.8.7"
  spec.authors       = ["HASHIMOTO, Naoki"]
  spec.email         = ["hashimoto.naoki@gmail.com"]
  spec.description   = %q{PseudoHikiParser is a parser of texts written in a Hiki like notation, and coverts them into HTML or other formats.}
  spec.summary       = %q{PseudoHikiParser: a parser of texts in a Hiki like notation.}
  spec.homepage      = "https://github.com/nico-hn/PseudoHikiParser/wiki"
  spec.license       = "Not decided yet"
  
  spec.files         = [
                        "lib/pseudohikiparser.rb",
                        "lib/pseudohiki/treestack.rb",
                        "lib/pseudohiki/inlineparser.rb",
                        "lib/pseudohiki/blockparser.rb",
                        "lib/pseudohiki/htmlformat.rb",
                        "lib/pseudohiki/plaintextformat.rb",
                        "lib/pseudohiki/version.rb",
                        "lib/pseudohiki/htmlplugin.rb",
                        "lib/htmlelement.rb",
                        "lib/htmlelement/htmltemplate.rb"
                       ]
  spec.executables   << "pseudohiki2html.rb"
  spec.test_files    = Dir.glob("test/test_*.rb")
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.3"
  spec.add_development_dependency "rake"
end