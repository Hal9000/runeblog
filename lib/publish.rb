require 'helpers-blog'
require 'runeblog'

class RuneBlog::Publishing
  attr_reader :user, :server, :docroot, :path

  BadRemoteLogin = Exception.new("Can't login remotely")
  BadRemotePerms = Exception.new("Bad remote permissions")

  def initialize(*params)
    @blog = RuneBlog.blog
    # Clunky...
    if params.size == 1 && params[0].is_a?(OpenStruct)
      obj = params[0]
      array = obj.to_h.values_at(:user, :server, :docroot, 
                                 :path, :proto)
      @user, @server, @docroot, @path, @proto = *array
    else
      @user, @server, @docroot, @path, @proto = *obj
    end
  end

  def to_h
    {user: @user, server: @server, docroot: @docroot,
     path: @path, proto: @proto}
  end

  def url
    url = "#{protocol}://#{@server}/#{@path}"
  end
 
  def publish(files)
    reset_output
    dir = "#@docroot/#@path"
    result = system("ssh #@user@#@server -x mkdir #{dir}") 
    list = files.join(' ')
    cmd = "scp -r #{list} #@user@##server:#{dir} >/dev/null 2>&1"
    output! "Publishing #{files.size} files...\n"
    result = system(cmd)
    raise PublishError unless result

    dump(files, "#{@blog.view.dir}/last_published")
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
    dir = "#@docroot/#@path"
    temp = "#@path/__only_testing" 
    try1 = system("ssh -o BatchMode=yes -o ConnectTimeout=1 #@user@#@server -x mkdir -p #{temp} >/dev/null 2>&1")
    return nil unless try1
    try2 = system("ssh -o BatchMode=yes -o ConnectTimeout=1 #@user@#@server -x rmdir #{temp} >/dev/null 2>&1")
    return nil unless try2
    true
  end
end


