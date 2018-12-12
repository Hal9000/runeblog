
# Reopening...

make_exception(:CantOpen,        "Can't open '$1'")
make_exception(:CantDelete,      "Can't open '$1'")
make_exception(:InternalError,   "Glitch: $1 got arg '$2'")
make_exception(:CantCopy,        "Can't copy $1 to $2")

module WithANSI
  def clear
    puts "\e[H\e[2J"  # clear screen  # CHANGE_FOR_CURSES?
  end

  def red(text)
    "\e[31m#{text}\e[0m"  # CHANGE_FOR_CURSES?
  end

  def blue(text)
    "\e[34m#{text}\e[0m"  # CHANGE_FOR_CURSES?
  end

  def bold(str)
    "\e[1m#{str}\e[22m"  # CHANGE_FOR_CURSES?
  end

end

module NoANSI

  def gets
    str = ""
    loop do
      ch = ::STDSCR.getch
      if ch == 10
        STDSCR.crlf
        break 
      end
      str << ch
    end
    str
  end

  def clear
#   puts "\e[H\e[2J"  # clear screen  # CHANGE_FOR_CURSES?
  end

  def red(text)
    text
  end

  def blue(text)
    text
  end

  def bold(str)
    str
  end
end


module RuneBlog::REPL
  include curses? ? NoANSI : WithANSI

  Patterns = 
    {"help"              => :cmd_help, 
     "h"                 => :cmd_help,
     "version"           => :cmd_version,
     "v"                 => :cmd_version,
     "list views"        => :cmd_list_views, 
     "lsv"               => :cmd_list_views, 

     "new view $name"    => :cmd_new_view,

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
# puts "#{rx} =~ #{cmd.inspect}  --> #{m.to_a.inspect}"
      result = m ? m.to_a : nil
      next unless result
      found = meth
      params = m[1]
    end
    meth = found || :cmd_INVALID
    params = cmd if meth == :cmd_INVALID
    [meth, params]
  end

  def error(err)
    str = "\n  Error: #{red(err)}"
    puts str  # CHANGE_FOR_CURSES?
    puts err.backtrace[0]  # CHANGE_FOR_CURSES?
  end

  def ask(prompt, meth = :to_s)
    print prompt
    gets.chomp.send(meth)
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
    puts @out  # CHANGE_FOR_CURSES?
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

  def output!(str)  # red, \n and indent
    @out ||= ""
    @out << "  " + red(str)
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
    red(slug[0..3])+blue(slug[4..-1])  # CHANGE_FOR_CURSES?
  end

  def import(arg = nil)
#   open_blog unless @blog
    raise "Not implemented at present..."
    arg = nil if arg == ""
    arg ||= ask("Filename: ")  # check validity later
    name = arg
    grep = `grep ^.title #{name}`
    @title = grep.sub(/^.title /, "")
    @slug = @blog.make_slug(@title)
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

  def dumb_menu(array)
    # { string => :meth, ... }
    max = array.size
    puts "\n  Select from:"  # CHANGE_FOR_CURSES?
    array.each.with_index do |string, i|
      puts "   #{red('%2d' % (i+1))} #{string}"  # CHANGE_FOR_CURSES?
    end
    picked = nil
    loop do
      print red("> ")  # CHANGE_FOR_CURSES?
      num = gets.to_i
      if num.between?(1, max)
        picked = array[num-1]
        break
      else
        puts "Huh? Must be 1 to #{max}"  # CHANGE_FOR_CURSES?
      end
    end
    picked
  end

  ### find_asset

#   def find_asset(asset)    # , views)
# # STDERR.puts "repl find_asset: @meta = #{@meta.inspect}"
#     views = @meta.views
#     views.each do |view| 
#       vdir = @config.viewdir(view)
#       post_dir = "#{vdir}#{@meta.slug}/assets/"
#       path = post_dir + asset
#       STDERR.puts "          Seeking #{path}"
#       return path if File.exist?(path)
#     end
#     views.each do |view| 
#       dir = @config.viewdir(view) + "/assets/"
#       path = dir + asset
#       STDERR.puts "          Seeking #{path}"
#       return path if File.exist?(path)
#     end
#     top = @root + "/assets/"
#     path = top + asset
#     STDERR.puts "          Seeking #{path}"
#     return path if File.exist?(path)
# 
#     return nil
#   end
# 
#   ### find_all_assets
# 
#   def find_all_assets(list, views)
# #   STDERR.puts "\n  Called find_all_assets with #{list.inspect}"
#     list ||= []
#     list.each {|asset| puts "#{asset} => #{find_asset(asset, views)}" }
#   end

end
