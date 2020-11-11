require 'logging'

class RuneBlog::View
  attr_reader :name, :state, :globals
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
    get_globals
  end

  def get_globals
    gfile = @blog.root/"views/#@name/themes/standard/global.lt3"
    return unless File.exist?(gfile)  # Hackish!! how is View.new called from create_view??

    live = Livetext.customize(call: ".nopara")
    live.xform_file(gfile)
    @globals = live.vars
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

  def can_publish?
    @can_publish
  end

  def recent?(file)
    File.mtime(file) > File.mtime("#{self.dir()}/last_published")
  rescue
    true
  end
end

