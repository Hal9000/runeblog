# require 'helpers-blog'
# require 'runeblog'
require 'global'

class RuneBlog::Publishing
  attr_reader :user, :server, :docroot, :path

  BadRemoteLogin = Exception.new("Can't login remotely")
  BadRemotePerms = Exception.new("Bad remote permissions")

  def initialize(*params)
    log!(enter: __method__, args: [*params])
    @blog = RuneBlog.blog
    # Clunky...
    if params.size == 1 && params[0].is_a?(OpenStruct)
      obj = params[0]
      array = obj.to_h.values_at(:user, :server, :docroot, 
                                 :path, :proto)
      @user, @server, @docroot, @path, @proto = *array
    else
      @user, @server, @docroot, @path, @proto = *params
    end
  end

  def to_h
    log!(enter: __method__)
    {user: @user, server: @server, docroot: @docroot,
     path: @path, proto: @proto}
  end

  def url
    log!(enter: __method__)
    vname = @blog.view.name # .gsub(/_/, "\\_")
    url = "#@proto://#@server/#@path/#{vname}"
  end

  def system!(str)
    log!(enter: __method__, args: [str])
    rc = system(str)
    rc
  end

  def publish(files, assets=[])
    log!(enter: __method__, args: [files, assets])
    dir = "#@docroot/#@path"
    view_name = @blog.view.name
    viewpath = "#{dir}/#{view_name}"
    result = system!("ssh #@user@#@server -x mkdir -p #{viewpath}") 
    result = system!("ssh #@user@#@server -x mkdir -p #{viewpath}/assets") 
    files.each do |file|
      dest = "#@user@#@server:#{dir}/#{view_name}"
      file.gsub!(/\/\//, "/")  # weird... :-/
      dest.gsub!(/\/\//, "/")  # weird... :-/
      cmd = "scp -r #{file} #{dest} >/dev/null 2>/tmp/wtf"
      debug "cmd = #{cmd.inspect}  - see /tmp/wtf"
      result = system!(cmd) || puts("\n  Could not copy #{file} to #{dest}")
    end
    unless assets.empty?
      cmd = "scp #{assets.join(' ')} #@user@#@server:#{viewpath}/assets >/dev/null 2>/tmp/wtf2"
      result = system!(cmd)
      raise PublishError if !result
    end
    dump(files, "#{@blog.view.dir}/last_published")
    true
  end

  def remote_login?
    log!(enter: __method__)
    cmd = "ssh -o BatchMode=yes #@user@#@server -x date >/dev/null 2>&1"
    result = system(cmd)
    return nil unless result
    true
  end

  def remote_permissions?
    log!(enter: __method__)
    dir = "#@docroot/#@path"
    temp = "#@path/__only_testing" 
    try1 = system("ssh -o BatchMode=yes -o ConnectTimeout=1 #@user@#@server -x mkdir -p #{temp} >/dev/null 2>&1")
    return nil unless try1
    try2 = system("ssh -o BatchMode=yes -o ConnectTimeout=1 #@user@#@server -x rmdir #{temp} >/dev/null 2>&1")
    return nil unless try2
    true
  end
end


