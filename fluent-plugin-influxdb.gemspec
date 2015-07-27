# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)

Gem::Specification.new do |s|
  s.name          = "fluent-plugin-influxdb"
  s.version       = '0.2.0'
  s.authors       = ["Masahiro Nakagawa", "FangLi"]
  s.email         = ["repeatedly@gmail.com", "surivlee@gmail.com"]
  s.description   = %q{InfluxDB output plugin for Fluentd}
  s.summary       = %q{A buffered output plugin for fluentd and influxDB}
  s.homepage      = "https://github.com/fangli/fluent-plugin-influxdb"
  s.license       = 'MIT'

  s.files         = `git ls-files`.split($/)
  s.executables   = s.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  s.test_files    = s.files.grep(%r{^(test|spec|features)/})
  s.require_paths = ["lib"]

  s.add_runtime_dependency "fluentd", [">= 0.10.49", "< 2"]
  s.add_runtime_dependency "influxdb", ">= 0.2.0"

  s.add_development_dependency "rake"
  s.add_development_dependency "pry"
  s.add_development_dependency "test-unit"
end
