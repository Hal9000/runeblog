# require 'helpers-blog'
# require 'runeblog'
require 'global'

class RuneBlog::View
  attr_reader :name, :state
  attr_accessor :publisher

  include RuneBlog::Helpers

  def initialize(name)
    raise NoBlogAccessor if RuneBlog.blog.nil?
    @blog = RuneBlog.blog
    @name = name
    @can_publish = false
    pub_file = @blog.root + "/views/#@name/publish"
    if File.exist?(pub_file) && File.size(pub_file) != 0
      @publisher = RuneBlog::Publishing.new(read_config(pub_file))
      @can_publish = true
    end
  end

  def dir
    @blog.root + "/views/#@name/"
  end

  def local_index
    dir + "/remote/index.html"
  end

  def index
    dir + "index.html"
  end

  def to_s
    @name
  end

  def publishable_files
    vdir = dir()
    files = [local_index()]
    others = Dir.entries(vdir + "/remote").grep(/^\d\d\d\d/).map {|x| "#{vdir}/remote/#{x}" }
abort "FIXME... publishable_files"
    deep_assets = Dir["#{vdir}/themes/standard/assets/*"]
    deep_assets.each do |file|   # Do this at view creation
      cmd = "cp #{file} #{vdir}/assets"
      system(cmd)
    end
    assets = Dir.entries("#{vdir}/assets") - %w[. ..]
    assets.map! {|x| "#{vdir}/assets/#{x}" }
    assets.reject! {|x| File.directory?(x) }
#   assets.reject! {|x| ! recent?(x) }
    files = files + others
    all = files.dup
    dirty = files.reject {|f| ! recent?(f) }
    [dirty, all, assets]
  end

  def can_publish?
    @can_publish
  end

  def recent?(file)
    File.mtime(file) > File.mtime("#{dir()}/last_published")
  rescue
    true
  end

end

