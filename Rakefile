require "bundler/gem_tasks"
require "rake/testtask"

desc "Run tests"
Rake::TestTask.new do |t|
  t.libs.push "repl"
  t.libs.push "test"
  t.libs.push "lib"
  t.test_files = FileList['test/*_test.rb']
  t.verbose = true
end

task default: :test

desc "Create Sample Blog"
task :create_sample do
  sh %{ruby test/make_blog.rb}
end
