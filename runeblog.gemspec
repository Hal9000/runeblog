require 'date'
require 'find'

$: << "."
require "lib/runeblog"

Gem::Specification.new do |s|
  system("rm -f *.gem")
  s.name        = 'runeblog'
  s.version     = RuneBlog::VERSION
  s.date        = Date.today.strftime("%Y-%m-%d")
  s.summary     = "A command-line blogging system"
  s.description = "A blog system based on Ruby and Livetext"
  s.authors     = ["Hal Fulton"]
  s.email       = 'rubyhacker@gmail.com'
  s.executables << "blog"
  s.add_runtime_dependency 'livetext', '~> 0.8', '>= 0.8.20'

  # Files...
  main = Find.find("bin").to_a + 
         Find.find("lib").to_a + 
         Find.find("data").to_a

  misc = %w[./README.lt3 ./README.md runeblog.gemspec]
  test = Find.find("test").to_a

  s.files       =  main + misc + test
STDERR.puts "Files are:"
s.files.each {|fn| STDERR.puts "  " + fn }
STDERR.puts
  s.homepage    = 'https://github.com/Hal9000/runeblog'
  s.license     = "Ruby's license"
end
