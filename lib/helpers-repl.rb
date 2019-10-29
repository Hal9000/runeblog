
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
     "clear"             => :cmd_clear,

     "new view $name"    => :cmd_new_view,

     "tags"              => :cmd_tags,
     "import"            => :cmd_import,

     "new post"          => :cmd_new_post,
     "p"                 => :cmd_new_post,
     "post"              => :cmd_new_post,

     "change view $name" => :cmd_change_view,
     "cv $name"          => :cmd_change_view,
     "cv"                => :cmd_change_view,  # 0-arity must come second

     "config"            => :cmd_config,
     "manage $widget"    => :cmd_manage,

     "legacy"            => :cmd_legacy,

     "list posts"        => :cmd_list_posts,
     "lsp"               => :cmd_list_posts,

     "list drafts"       => :cmd_list_drafts,
     "lsd"               => :cmd_list_drafts,

     "list assets"       => :cmd_list_assets,
     "lsa"               => :cmd_list_assets,

     "pages"             => :cmd_pages,

     "delete >postid"    => :cmd_remove_post,
     "undel $postid"     => :cmd_undelete_post,

     "edit $postid"      => :cmd_edit_post,
     "ed $postid"        => :cmd_edit_post,
     "e $postid"         => :cmd_edit_post,

     "preview"           => :cmd_preview,

     "browse"            => :cmd_browse,

     "rebuild"           => :cmd_rebuild,

     "publish"           => :cmd_publish,

     "ssh"               => :cmd_ssh,

     "q"                 => :cmd_quit,
     "quit"              => :cmd_quit
   }

  Abbr = {
     "h"                 => :cmd_help,
     "v"                 => :cmd_version,
     "lsv"               => :cmd_list_views, 
     "p"                 => :cmd_new_post,
     "cv $name"          => :cmd_change_view,
     "cv"                => :cmd_change_view,  # 0-arity must come second
     "lsp"               => :cmd_list_posts,
     "lsd"               => :cmd_list_drafts,
     "list assets"       => :cmd_list_assets,
     "lsa"               => :cmd_list_assets,
     "rm $postid"        => :cmd_remove_post,
     "ed $postid"        => :cmd_edit_post,
     "e $postid"         => :cmd_edit_post,
     "q"                 => :cmd_quit
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
# puts "choose: #{[meth, params].inspect}"
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
    CantOpen
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

  def tags_for_view(vname = @blog.view)
    Dir.chdir(vname) do
      fname = "tagpool"
      if File.exist?(fname)
        tags = File.readlines(fname).map(&:chomp)
      else
        tags = []
      end
    end
    tags.sort
  end

  def all_tags
    all = []
    @blog.views.each {|view| all.append(*tags_for_view(view)) }
    all.sort + ["NEW TAG"]
  end

end
