if ! defined?(Already_publish)

  Already_publish = nil

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
    # Please refactor the Hal out of this
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

  def publish
    log!(enter: __method__, level: 1)
    dir = @docroot/@path
    view_name = @blog.view.name
    viewpath = dir # /view_name
    # FIXME rsync doesn't work
    cmd = "rsync -a -r -z #{@blog.root}/views/#{@blog.view}/remote/ #@user@#@server:#{viewpath}/"
    system!(cmd)
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

end
