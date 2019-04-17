require "bundler/gem_tasks"
require "rake/testtask"

desc "Run tests"
Rake::TestTask.new do |t|
  t.libs.push "repl"
  t.libs.push "test"
  t.libs.push "lib"
  t.test_files = FileList['test/*_test.rb']
  t.verbose = true
  t.warning = false
end

task default: :test

desc "Create sample blog"
task :create_sample do
  system %{ruby test/make_blog.rb}
  puts
end

desc "Bump gem version"
task :bump do
  sh "./bump-gem"
end
