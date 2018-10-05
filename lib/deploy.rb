require 'helpers-blog'
require 'runeblog'

class RuneBlog::Deployment
  attr_reader :user, :server, :root, :path

  BadRemoteLogin = Exception.new("Can't login remotely")
  BadRemotePerms = Exception.new("Bad remote permissions")

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
    result = system("ssh #@user@#@server -x mkdir #{dir}") 
    list = files.join(' ')
    cmd = "scp -r #{list} #@user@##server:#{dir} >/dev/null 2>&1"
    output! "Deploying #{files.size} files...\n"
    result = system(cmd)
    raise "Problem occurred in deployment" unless result

    File.write("#{@blog.view.dir}/last_deployed", files)
    output! "...finished.\n"
    @out
  end

  def remote_login?
    cmd = "ssh -o BatchMode=yes #@user@#@server -x date >/dev/null 2>&1"
    result = system(cmd)
    return nil unless result
    true
  end

  def remote_permissions?
    dir = "#@root/#@path"
    temp = "#@path/__only_testing" 
    try1 = system("ssh -o BatchMode=yes -o ConnectTimeout=2 #@user@#@server -x mkdir -p #{temp} >/dev/null 2>&1")
    return nil unless try1
    try2 = system("ssh -o BatchMode=yes -o ConnectTimeout=2 #@user@#@server -x rmdir #{temp} >/dev/null 2>&1")
    return nil unless try2
    true
  end
end


