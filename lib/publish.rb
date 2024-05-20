if ! defined?(Already_publish)

  Already_publish = nil

require 'pathmagic'
require 'processing'

class RuneBlog::Publishing
  attr_reader :user, :server, :docroot, :path

  BadRemoteLogin = Exception.new("Can't login remotely")
  BadRemotePerms = Exception.new("Bad remote permissions")

  def initialize(view)
    log!(enter: __method__, args: [view.to_s])
    @blog = RuneBlog.blog
    # CHANGED redefining "global" location
    dir = @blog.root/:views/view  # /"themes/standard/"
    gfile = dir/"global.lt3"
    raise MissingGlobal unless File.exist?(gfile)

    live = get_live_vars(gfile)
    @user    = live.vars["publish.user"]
    @server  = live.vars["publish.server"]
    @docroot = live.vars["publish.docroot"]
    @path    = live.vars["publish.path"]
    @proto   = live.vars["publish.proto"]
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

  def check_new_posts
    # How do we know??
    # If it's newly published:
    #   autopost on reddit   (if enabled and not already)
    #       "    "  twitter  (if enabled and not already)
    #       "    "  facebook (if enabled and not already)
  end

  def publish
    log!(enter: __method__, level: 1)
    dir = @docroot/@path
    view_name = @blog.view.name
    viewpath = dir 
    cmd = "rsync -r -z #{@blog.root}/views/#{@blog.view}/remote/ #@user@#@server:#{viewpath}/"
    system!(cmd)
    check_new_posts
    dump("#{@blog.view} at #{Time.now}", "#{@blog.view.dir}/last_published")
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
