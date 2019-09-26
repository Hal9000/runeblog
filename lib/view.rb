# require 'helpers-blog'
# require 'runeblog'
require 'global'

class RuneBlog::View
  attr_reader :name, :state
  attr_accessor :publisher

  include RuneBlog::Helpers

  def initialize(name)
    log!(enter: __method__, args: [name])
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
#   log!(enter: __method__)
    @blog.root + "/views/#@name/"
  end

  def local_index
    log!(enter: __method__)
    dir + "/remote/index.html"
  end

  def index
    log!(enter: __method__)
    dir + "index.html"
  end

  def to_s
    log!(enter: __method__)
    @name
  end

  def publishable_files
    log!(enter: __method__)
    vdir = dir()
    remote = local_index()
    files = [remote]
    others = Dir.entries(vdir + "/remote").map {|x| "#{vdir}/remote/#{x}" }

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
    log!(enter: __method__)
    @can_publish
  end

  def recent?(file)
    log!(enter: __method__, args: [file])
    File.mtime(file) > File.mtime("#{dir()}/last_published")
  rescue
    true
  end

end

