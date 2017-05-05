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

  File.write("data/VERSION", "RuneBlog v #{s.version}   #{s.date}")
  
  # Files...
  main = Find.find("bin").to_a + 
         Find.find("lib").to_a + 
         Find.find("data").to_a
  misc = %w[./README.lt3 ./README.md runeblog.gemspec]
  test = Find.find("test").to_a

  s.files       =  main + misc + test
  s.homepage    = 'https://github.com/Hal9000/runeblog'
  s.license     = "Ruby's license"
  puts "Files:"
  puts s.files
end
