require 'logging'

class RuneBlog::View
  attr_reader :name, :state
  attr_accessor :publisher, :globals

  include RuneBlog::Helpers

  def initialize(name)
    log!(enter: __method__, args: [name], level: 3)
    raise NoBlogAccessor if RuneBlog.blog.nil?
    @blog = RuneBlog.blog
    @name = name
    @publisher = RuneBlog::Publishing.new(name)
    @can_publish = true  # FIXME
    #  @blog.view = self  # NOOOO??
    get_globals
  rescue => err
    fatal(err)
  end

  def dump_globals_stderr
    log!(enter: __method__, args: [list], level: 2)
    list2 = list.select(&block)
    STDERR.puts "-- globals = "
    log!(str: "-- globals = ")
    @globals.each_pair do |k, v| 
      msg = sprintf "     %-10s  %s\n", k, v if k.is_a? Symbol 
      STDERR.puts msg
    log!(str: msg)
    end
    STDERR.puts 
    log!(str: "")
  rescue => err
    fatal(err)
  end

  def get_globals(force = false)
    return if @globals && !force

    gfile = @blog.root/"views/#@name/global.lt3"
    return unless File.exist?(gfile)  # Hackish!! how is View.new called from create_view??

    live = Livetext.customize(call: ".nopara")
    live.xform_file(gfile)
    live.setvar("ViewDir", @blog.root/:views/@name)
    live.setvar("View",    @name)
    @globals = live.vars
#   dump_globals_stderr
  rescue => err
    fatal(err)
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

