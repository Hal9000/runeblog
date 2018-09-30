require 'helpers-blog'
require 'runeblog'

class RuneBlog::Deployment
  attr_reader :user, :server, :root, :path

  def initialize(user, server, root, path, protocol = "http")
    @blog = RuneBlog.blog
    @user, @server, @root, @path = 
      user, server, root, path
  end

  def url
    url = "#{protocol}://#{@server}/#{@path}"
  end
 
  def deploy(files)
    reset_output
    dir = "#@root/#@path"
    result = system("ssh -c #@user@#@server mkdir #{dir}") 
    list = files.join(' ')
    cmd = "scp -r #{list} root@#{server}:#{dir} >/dev/null 2>&1"
    output! "Deploying #{files.size} files...\n"
    result = system(cmd)
    raise "Problem occurred in deployment" unless result

    File.write("#{@blog.view.dir}/last_deployed", files)
    output! "...finished.\n"
    @out
  end
end


