$: << "."

require '../lib/runeblog'

require 'yaml'

oldfile = ARGV.first

meta = YAML.load(File.read(oldyaml))

p meta

