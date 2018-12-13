require 'helpers-blog'
require 'runeblog'

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
    unless File.size(pub_file) == 0
      @publisher = RuneBlog::Publishing.new(read_config(pub_file))
      @can_publish = true
    end
  end

  def dir
    @blog.root + "/views/#@name/"
  end

  def index
    dir + "index.html"
  end

  def to_s
    @name
  end

  def files(recent = false)
    vdir = dir()
    files = [index()]
debug "Looking in #{vdir}"
    others = Dir.entries(vdir).grep(/^\d\d\d\d/)
    files += others.map {|x| "#{vdir}/#{x}" }
debug "Found #{files.inspect}"
#   files.reject! {|f| recent?(f) } if recent
debug "Now files = #{files.inspect}"
    files
  end

  def can_publish?
    @can_publish
  end

  def publish
    # ?? @blog.view.publisher.publish
    # output "Files:"
    # files.each {|f| output "    #{f}\n" }
    output_newline
    list = files(true)
    @publisher.publish(list)
  rescue => err
    error(err)
  end

  def recent?(file)
    File.mtime(file) < File.mtime("#{dir()}/last_published")
  end

end

