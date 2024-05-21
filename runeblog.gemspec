require 'date'
require 'find'

$LOAD_PATH << "lib"

require "runeblog_version"

Gem.post_install do |spec|
  Dir.chdir(RuneBlog::Path)
  # FIXME - depends on livetext being installed
  #         How to deal with this??
  system("livetext -i liveblog.rb")
  system("livetext -i code_rouge.rb")
end

spec = Gem::Specification.new do |s|
  system("rm -f *.gem")
  s.name        = 'runeblog'
  s.version     = RuneBlog::VERSION
  s.date        = Date.today.strftime("%Y-%m-%d")
  s.summary     = "A command-line blogging system"
  s.description = "A blog system based on Ruby and Livetext"
  s.authors     = ["Hal Fulton"]
  s.email       = 'rubyhacker@gmail.com'
  s.executables << "blog"
  s.add_runtime_dependency 'livetext', '~> 0.9',  '>= 0.9.45'
  s.add_runtime_dependency 'rubytext', '~> 0.1',  '>= 0.1.27'
  s.add_runtime_dependency 'rouge',    '~> 3.25', '>= 3.25.0'

  s.add_development_dependency 'minitest', '~> 5.20', '>= 5.20.0'

  # Files...
  main = Find.find("bin").to_a + 
         Find.find("lib").to_a
  data = Find.find("data").to_a
  test = Find.find("test").to_a
  misc = %w[./README.lt3 ./README.md ./runeblog.gemspec]
  empty_view = Find.find("empty_view").to_a

  s.files       =  main + misc + data + test + empty_view
  s.homepage    = 'https://github.com/Hal9000/runeblog'
  s.license     = "Ruby"
  s.post_install_message = "\n  Success! Run 'blog' command and type h for help.\n "
end

spec
