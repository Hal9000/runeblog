
# Reopening...

make_exception(:CantOpen,        "Can't open '$1'")
make_exception(:CantDelete,      "Can't open '$1'")
make_exception(:InternalError,   "Glitch: $1 got arg '$2'")
make_exception(:CantCopy,        "Can't copy $1 to $2")


module RuneBlog::REPL
  Patterns = 
    {"help"              => :cmd_help, 
     "h"                 => :cmd_help,
     "version"           => :cmd_version,
     "v"                 => :cmd_version,
     "list views"        => :cmd_list_views, 
     "lsv"               => :cmd_list_views, 

     "new view $name"    => :cmd_new_view,

     "customize"         => :cmd_customize,

     "new post"          => :cmd_new_post,
     "p"                 => :cmd_new_post,
     "post"              => :cmd_new_post,

     "change view $name" => :cmd_change_view,
     "cv $name"          => :cmd_change_view,
     "cv"                => :cmd_change_view,  # 0-arity must come second

     "config"            => :cmd_config,

     "list posts"        => :cmd_list_posts,
     "lsp"               => :cmd_list_posts,

     "list drafts"       => :cmd_list_drafts,
     "lsd"               => :cmd_list_drafts,

     "rm $postid"        => :cmd_remove_post,
     "undel $postid"     => :cmd_undelete_post,

     "kill >postid"      => :cmd_kill, 

     "edit $postid"      => :cmd_edit_post,
     "ed $postid"        => :cmd_edit_post,
     "e $postid"         => :cmd_edit_post,

     "preview"           => :cmd_preview,

     "pre"               => :cmd_preview,

     "browse"            => :cmd_browse,

     "relink"            => :cmd_relink,

     "rebuild"           => :cmd_rebuild,

     "publish"           => :cmd_publish,

     "ssh"               => :cmd_ssh,

     "q"                 => :cmd_quit,
     "quit"              => :cmd_quit
   }
  
  Regexes = {}
  Patterns.each_pair do |pat, meth|
    rx = "^" + pat
    rx.gsub!(/ /, " +")
    rx.gsub!(/\$(\w+) */) { " *(?<#{$1}>\\w+)" }
    # How to handle multiple optional args?
    rx.sub!(/>(\w+)$/) { "(.+)" }
    rx << "$"
    rx = Regexp.new(rx)
    Regexes[rx] = meth
  end

  def self.choose_method(cmd)
    cmd = cmd.strip
    found = nil
    params = nil
    Regexes.each_pair do |rx, meth|
      m = cmd.match(rx)
      result = m ? m.to_a : nil
      next unless result
      found = meth
      params = m[1]
    end
    meth = found || :cmd_INVALID
    params = cmd if meth == :cmd_INVALID
    [meth, params]
  end

  def error(err)  # Hmm, this is duplicated
    str = "\n  Error: #{err}"
    puts str
    puts err.backtrace.join("\n")
  end

  def ask(prompt, meth = :to_s)
    print prompt
    str = gets
    str.chomp!
    str.send(meth)
  end

  def yesno(prompt, meth = :to_s)
    print prompt
    gets.chomp.upcase[0] == "Y"
  end

  def reset_output(initial = "")
    @out ||= ""
    @out.replace initial
  end

  def flush_output(initial = "")
    @out ||= ""
    puts @out
    reset_output
  end

  def output(str)  # \n and indent
    @out ||= ""
    @out << "  " + str.to_s
  end

  def outstr(str)  # indent
    @out ||= ""
    @out << str
  end

  def output!(str)  # \n and indent
    @out ||= ""
    @out << "  " + str
  end

  def output_newline(n = 1)
    @out ||= ""
    n.times { @out << "\n" }
  end


  def check_empty(arg)
    raise InternalError(caller[0], arg.inspect)  unless arg.nil?
  end

  def get_integer(arg)
    Integer(arg) 
  rescue 
    raise ArgumentError, "'#{arg}' is not an integer"
  end

  def check_file_exists(file)
    raise FileNotFound(file) unless File.exist?(file)
  end

  def error_cant_delete(files)
    case files
      when String
        raise CantDelete(files)
      when Array
        raise CantDelete(files.join("\n"))
    end
  end

  def colored_slug(slug)
    slug[0..3] + slug[4..-1]
  end

  def import(arg = nil)
    raise "Not implemented at present..."
    arg = nil if arg == ""
    arg ||= ask("Filename: ")  # check validity later
    name = arg
    grep = `grep ^.title #{name}`
    @title = grep.sub(/^.title /, "")
    @slug = @blog.make_slug(@title) # import (not impl)
    @fname = @slug + ".lt3"
    result = system("cp #{name} #@root/src/#@fname")
    raise CantCopy(name, "#@root/src/#@fname") unless result

    edit_initial_post(@fname)
    process_post(@fname)
    link_post_all_views(@meta)
  rescue => err
    error(err)
  end

  def ask_publishing_info   # returns Publishing object
    verify(@blog => "@blog is nil", 
           @blog.view => "@blog.view is nil")
    # user, server, root, path, protocol = "http"
    puts "Please enter publishing data for view #{@blog.view}..."
    user = ask("User: ")
    root = ask("Doc root: ")
    server = ask("Server: ")
    path = ask("View path: ")
    proto = ask("Protocol (ENTER for http): ")
    [user, root, server, path, proto].each {|x| x.chomp! }
    proto = "http" if proto.empty?
    RuneBlog::Publishing.new(user, server, root, path, proto)
  end

  ### find_asset

  # FIXME is this per-post?

  def find_asset(asset_name)    # , views)
    search_path = proc do |path| 
      full_path = path + asset_name
      return full_path if File.exist?(full_path)
    end 
    check_meta(@meta, "find_asset")
    views = @meta.views
    views.each do |view| search_path.call("#{view.dir}/#{@meta.slug}/assets/") end
    views.each do |view| search_path.call(view.dir + "/assets/") end
    search_path.call(@root + "/assets/", asset_name)
    # If all fail... return nil
    return nil
  end

  ### find_all_assets

  def find_all_assets(list, views)
    list ||= []
    list.each {|asset| puts "#{asset} => #{find_asset(asset, views)}" }
  end
end
