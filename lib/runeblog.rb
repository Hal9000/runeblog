require 'find'
require 'yaml'
require 'livetext'

class RuneBlog
  VERSION = "0.0.33"

  Path  = File.expand_path(File.join(File.dirname(__FILE__)))
  DefaultData = Path + "/../data"

  BlogHeader  = File.read(DefaultData + "/custom/blog_header.html")  rescue "not found"
  BlogTrailer = File.read(DefaultData + "/custom/blog_trailer.html") rescue "not found"
end

class RuneBlog::Config
  attr_reader :root, :views, :view, :sequence

  def initialize(cfg_file = ".blog")
    # What views are there? Deployment, etc.
    # Crude - FIXME later
    new_blog! unless File.exist?(cfg_file)

    lines = File.readlines(cfg_file).map {|x| x.chomp }
    @root = lines[0]
    @view = lines[1]
    dirs = Dir.entries("#@root/views/") - %w[. ..]
    dirs.reject! {|x| ! File.directory?("#@root/views/#{x}") }
    @root = root
    @views = dirs
    @sequence = File.read(root + "/sequence").to_i
  end

  def next_sequence
    @sequence += 1
    File.open("#@root/sequence", "w") {|f| f.puts @sequence }
    @sequence
  end

  def viewdir(v)
    @root + "/views/#{v}/"
  end

end

