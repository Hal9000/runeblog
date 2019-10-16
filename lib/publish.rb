require 'global'
require 'pathmagic'

class RuneBlog::Publishing
  attr_reader :user, :server, :docroot, :path

  BadRemoteLogin = Exception.new("Can't login remotely")
  BadRemotePerms = Exception.new("Bad remote permissions")

  def initialize(view)
    log!(enter: __method__, args: [view.to_s])
    @blog = RuneBlog.blog
    gfile = @blog.root/:views/view/"themes/standard/global.lt3"
    data = File.readlines(gfile)
    grab = ->(var) { data.grep(/^#{var} /).first.chomp.split(" ", 2)[1] }
    @user    = grab.call("publish.user")
    @server  = grab.call("publish.server")
    @docroot = grab.call("publish.docroot")
    @path    = grab.call("publish.path")
    @proto   = grab.call("publish.proto")
  end

  def to_h
    log!(enter: __method__, level: 3)
    {user: @user, server: @server, docroot: @docroot,
     path: @path, proto: @proto}
  end

  def url
    log!(enter: __method__, level: 3)
    vname = @blog.view.name # .gsub(/_/, "\\_")
    url = "#@proto://#@server/#@path"  # /#{vname}"
  end

  def system!(str)
    log!(enter: __method__, args: [str], level: 1)
    rc = system(str)
    rc
  end

  def publish(files, assets=[])
    log!(enter: __method__, args: [files, assets], level: 1)
    dir = @docroot/@path
    view_name = @blog.view.name
    viewpath = dir # /view_name
#   result = system!("ssh #@user@#@server -x mkdir -p #{viewpath}") 
    result = system!("ssh #@user@#@server -x mkdir -p #{viewpath}/assets") 
    files.each do |file|
      dest = "#@user@#@server:" + dir  # /view_name
      file.gsub!(/\/\//, "/")  # weird... :-/
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
    dir = @docroot/@path
    temp = @path/"__only_testing" 
    try1 = system("ssh -o BatchMode=yes -o ConnectTimeout=1 #@user@#@server -x mkdir -p #{temp} >/dev/null 2>&1")
    return nil unless try1
    try2 = system("ssh -o BatchMode=yes -o ConnectTimeout=1 #@user@#@server -x rmdir #{temp} >/dev/null 2>&1")
    return nil unless try2
    true
  end
end

