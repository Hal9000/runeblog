require 'global'
require 'logging'

class RuneBlog::View
  attr_reader :name, :state
  attr_accessor :publisher

  include RuneBlog::Helpers

  def initialize(name)
    log!(enter: __method__, args: [name], level: 3)
    raise NoBlogAccessor if RuneBlog.blog.nil?
    @blog = RuneBlog.blog
    @name = name
    @publisher = RuneBlog::Publishing.new(name)
    @can_publish = true  # FIXME
    @blog.view = self
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
    log!(enter: __method__, level: 2)
    vdir = dir()
    remote = local_index()
    files = [remote]
    others = Dir.entries(vdir/:remote) - %w[. ..]
    others.map! {|x| "#{vdir}/remote/#{x}" }

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
    File.mtime(file) > File.mtime("#{self.dir()}/last_published")
  rescue
    true
  end
end

