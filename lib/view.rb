require 'helpers-blog'
require 'runeblog'

class RuneBlog::View
  attr_reader :name, :state
  attr_accessor :deployer

  def initialize(name)
    raise "RuneBlog.blog is not set!" if RuneBlog.blog.nil?
    @blog = RuneBlog.blog
    @name = name
    dep_file = @blog.root + "/views/#@name/deploy"
    @deployer = read_config(dep_file)
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
    others = Dir.entries(vdir).grep(/^\d\d\d\d/)
    files += others.map {|x| "#{vdir}/#{x}" }
    files.reject! {|f| recent?(f) } if recent
    files
  end

  def deploy
    # ?? @blog.view.deployment.deploy
    # output "Files:"
    # files.each {|f| output "    #{f}\n" }
    output_newline
    list = files(true)
    @deployer.deploy(list)
  rescue => err
    error(err)
  end

  def recent?(file)
    File.mtime(file) < File.mtime("#{dir()}/last_deployed")
  end

end

