require 'runeblog'
require 'global'
require 'ostruct'
require 'helpers-repl'  # FIXME structure

make_exception(:PublishError,  "Error during publishing")
make_exception(:EditorProblem, "Could not edit $1")

module RuneBlog::REPL
  def edit_file(file, vim: "")
    STDSCR.saveback
    ed = @blog.editor
    params = vim if ed =~ /vim$/
    result = system!("#{@blog.editor} #{file} #{params}")
    raise EditorProblem(file) unless result
    STDSCR.restback
#   cmd_clear(nil)
  end

  def cmd_quit(arg, testing = false)
    cmd_clear(nil)
    RubyText.stop
    sleep 0.1
    
    sleep 0.1
    exit
  end

  def cmd_clear(arg, testing = false)
#   STDSCR.rows.times { puts " "*(STDSCR.cols-1) }
    STDSCR.clear
  end

  def cmd_version(arg, testing = false)
    reset_output
    output RuneBlog::VERSION
    puts fx("\n  RuneBlog", :bold), fx(" v #{RuneBlog::VERSION}\n", Red) unless testing
    @out
  end

  def cmd_config(arg, testing = false)
    list = ["global.lt3           Global configuration",
            "blog/generate.lt3    Generator for view (usu not edited)",
            ".... head.lt3        HEAD info for view",
            ".... banner.lt3      banner description",
            ".... index.lt3       User-edited detail for view",
            ".... post_entry.lt3  Generator for post entry in recent-posts",
            "etc/blog.css.lt3     Global CSS",
            "... externals.lt3    External JS/CSS (Bootstrap, etc.)",
            "post/generate.lt3    Generator for a post",
            ".... head.lt3        HEAD info for post",
            ".... index.lt3       Content for post",
            ".... permalink.lt3   Generator for permalink"]

    name = ["global.lt3", "blog/generate.lt3", "blog/head.lt3", "blog/banner.lt3", 
            "blog/index.lt3", "blog/post_entry.lt3", "etc/blog.css.lt3", 
            "blog/externals.lt3", "post/generate.lt3", "post/head.lt3", 
            "post/index.lt3", "post/permalink.lt3"]

    dir = @blog.view.dir/"themes/standard/"
    num, str = STDSCR.menu(title: "Edit file:", items: list)
    target = name[num]
    edit_file(dir/target)
  end

  def cmd_manage(arg, testing = false)
    case arg
      when "pages";   _manage_pages(nil, testing = false)
      when "links";   _manage_links(nil, testing = false)
      when "navbar";  _manage_navbar(nil, testing = false)
#     when "pinned";  _manage_pinned(nil, testing = false)  # ditch this??
    else
      puts "#{arg} is unknown"
    end
  end

  def _manage_pinned(arg, testing = false)   # cloned from manage_links
    dir = @blog.view.dir/"themes/standard/widgets/pinned"
    data = dir/"list.data"
    edit_file(data)
  end

  def _manage_navbar(arg, testing = false)   # cloned from manage_pages
    dir = @blog.view.dir/"themes/standard/navbar"
    files = Dir.entries(dir) - %w[. .. navbar.lt3]
    new_item = "  [New item]  "
    main_file = "[ navbar.lt3 ]"
    files = [main_file] + files + [new_item]
    num, fname = STDSCR.menu(title: "Edit navbar:", items: files)
    return if fname.nil?
    case fname
      when new_item
        print "Page title:  "
        title = RubyText.gets
        title.chomp!
        print "File name (.lt3): "
        fname = RubyText.gets
        fname << ".lt3" unless fname.end_with?(".lt3")
        new_file = dir/fname
        File.open(new_file, "w") do |f|
          f.puts "<h1>#{title}</h1>\n\n\n "
          f.puts ".backlink"
        end
        edit_file(new_file)
      when main_file
        edit_file(main_file[2..-3])
    else
      edit_file(dir/fname)
    end
  end

  def _manage_links(arg, testing = false)
    dir = @blog.view.dir/"themes/standard/widgets/links"
    data = dir/"list.data"
    edit_file(data)
  end

  def _manage_pages(arg, testing = false)
    dir = @blog.view.dir/"themes/standard/widgets/pages"
    # Assume child files already generated (and list.data??)
    data = dir/"list.data"
    lines = File.readlines(data)
    hash = {}
    lines.each do |line|
      url, name = line.chomp.split(",")
      source = url.sub(/.html$/, ".lt3")
      hash[name] = source
    end
    new_item = "[New page]"
    num, fname = STDSCR.menu(title: "Edit page:", items: hash.keys + [new_item])
    return if fname.nil?
    if fname == new_item
      print "Page title:  "
      title = RubyText.gets
      title.chomp!
      print "File name (.lt3): "
      fname = RubyText.gets
      fname << ".lt3" unless fname.end_with?(".lt3")
      fhtml = fname.sub(/.lt3$/, ".html")
      File.open(data, "a") {|f| f.puts "#{fhtml},#{title}" }
      new_file = dir/fname
      File.open(new_file, "w") do |f|
        f.puts "<h1>#{title}</h1>\n\n\n "
        f.puts ".backlink"
      end
      edit_file(new_file)
    else
      target = hash[fname]
      edit_file(dir/target)
    end
  end

  def cmd_import(arg, testing = false)
    files = ask("\n  File(s) = ")
    system!("cp #{files} #{@blog.root}/views/#{@blog.view.name}/assets/")
  end

  def cmd_browse(arg, testing = false)
    reset_output
    url = @blog.view.publisher.url
    if url.nil?   
      output! "Publish first."
      puts "\n  Publish first."
      return @out
    end
    result = system!("open '#{url}'")
    raise CantOpen(url) unless result
    return @out
  end

  def cmd_preview(arg, testing = false)
    reset_output
    local = @blog.view.local_index
    unless File.exist?(local)
      puts "\n  No index. Rebuilding..."
      cmd_rebuild(nil)
    end
    result = system!("open #{local}")
    raise CantOpen(local) unless result
    @out
  rescue => err
    out = "/tmp/blog#{rand(100)}.txt"
    File.open(out, "w") do |f|
      f.puts err
      f.puts err.backtrace.join("\n")
    end
    puts "Error: See #{out}"
  end

  def cmd_publish(arg, testing = false)
# Future Hal says please refactor this
    puts unless testing
    reset_output
    unless @blog.view.can_publish?
      msg = "Can't publish... see globals.lt3"
      puts msg unless testing
      output! msg
      return @out
    end

    # Need to check dirty/clean status first
    dirty, all, assets = @blog.view.publishable_files
    files = dirty
    if dirty.empty?
      puts fx("\n  No files are out of date." + " "*20, :bold)
      print "  Publish anyway? "
      yn = RubyText.gets.chomp
      files = all if yn == "y"
    end
    return @out if files.empty?

    ret = RubyText.spinner(label: " Publishing... ") do
      @blog.view.publisher.publish(files, assets)  # FIXME weird?
    end
    return @out unless ret

    vdir = @blog.view.dir
    dump("fix this later", "#{vdir}/last_published")
    if ! testing || ! ret
      puts "  ...finished.\n " 
      output! "...finished.\n"
    end
    return @out
  rescue => err
    out = "/tmp/blog#{rand(100)}.txt"
    File.open(out, "w") do |f|
      f.puts err
      f.puts err.backtrace.join("\n")
    end
    puts "Error: See #{out}"
  end

  def cmd_rebuild(arg, testing = false)
    debug "Starting cmd_rebuild..."
    reset_output
    puts unless testing
    @blog.generate_view(@blog.view)
    @blog.generate_index(@blog.view)
    @out
  rescue => err
    out = "/tmp/blog#{rand(100)}.txt"
    File.open(out, "w") do |f|
      f.puts err
      f.puts err.backtrace.join("\n")
    end
    puts "Error: See #{out}"
  end

  def cmd_change_view(arg, testing = false)
    reset_output
    # Simplify this
    if arg.nil?
      viewnames = @blog.views.map {|x| x.name }
      n = viewnames.find_index(@blog.view.name)
      name = @blog.view.name
      k, name = STDSCR.menu(title: "Views", items: viewnames, curr: n) unless testing
      return if name.nil?
      @blog.view = name
      output name + "\n"
      puts "\n  ", fx(name, :bold), "\n" unless testing
      return @out
    else
      if @blog.view?(arg)
        @blog.view = arg
        output "View: " + @blog.view.name.to_s
        puts "\n  ", fx(arg, :bold), "\n" unless testing
      end
    end
    return @out
  end

  def cmd_new_view(arg, testing = false)
    reset_output
    if arg.nil?
      arg = ask("\nFilename: ")
      puts
    end
    @blog.create_view(arg)
    vim_params = '-c ":set hlsearch" -c ":hi Search ctermfg=2 ctermbg=6" +/"\(VIEW_.*\|SITE.*\)"'
    edit_file(@blog.view.dir/"themes/standard/global.lt3", vim: vim_params)
    @blog.change_view(arg)
    @out
  rescue ViewAlreadyExists
    puts 'Blog already exists'
  rescue => err
    out = "/tmp/blog#{rand(100)}.txt"
    File.open(out, "w") do |f|
      f.puts err
      f.puts err.backtrace.join("\n")
    end
    puts "Error: See #{out}"
  end

  def cmd_new_post(arg, testing = false)
    reset_output
    if @blog.views.empty?
      puts "\n  Create a view before creating the first post!\n "
      return
    end
    title = ask("\nTitle: ")
    puts
    @blog.create_new_post(title)
#   STDSCR.clear
    @out
  rescue => err
    out = "/tmp/blog#{rand(100)}.txt"
    File.open(out, "w") do |f|
      f.puts err
      f.puts err.backtrace.join("\n")
    end
    puts "Error: See #{out}"
  end

  def _remove_post(arg, testing=false)
    id = get_integer(arg)
    result = @blog.remove_post(id)
    puts "Post #{id} not found" if result.nil?
  end

  def cmd_remove_post(arg, testing = false)
    reset_output
    args = arg.split
    args.each do |x| 
      # FIXME
      ret = _remove_post(x.to_i, false)
      puts ret
      output ret
    end
    @out
  end

  def cmd_edit_post(arg, testing = false)
    reset_output
    id = get_integer(arg)
    # Simplify this
    tag = "#{'%04d' % id}"
    files = ::Find.find(@blog.root/:drafts).to_a
    files = files.grep(/#{tag}-.*lt3/)
    files = files.map {|f| File.basename(f) }
    if files.size > 1
      msg = "Multiple files: #{files}"
      output msg
      puts msg unless testing
      return [false, msg]
    end
    if files.empty?
      msg = "\n  Can't edit post #{id}"
      output msg
      puts msg unless testing
      return [false, msg]
    end

    file = files.first
    draft = @blog.root/:drafts/file
    vim_params = '-c G'
    result = edit_file(draft)
    @blog.generate_post(draft)
  rescue => err
    out = "/tmp/blog#{rand(100)}.txt"
    File.open(out, "w") do |f|
      f.puts err
      f.puts err.backtrace.join("\n")
    end
    puts "Error: See #{out}"
  end

  def cmd_list_views(arg, testing = false)
    reset_output("\n")
    puts unless testing
    @blog.views.each do |v| 
      v = v.to_s
      v = fx(v, :bold) if v == @blog.view.name
      output v + "\n"
      puts "  ", v unless testing
    end
    puts unless testing
    @out
  end

  def cmd_list_posts(arg, testing = false)
    reset_output
    posts = @blog.posts  # current view
    str = @blog.view.name + ":\n"
    output str
    puts unless testing
    puts "  ", fx(str, :bold) unless testing
    if posts.empty?
      output! "No posts"
      puts "  No posts" unless testing
    else
      posts.each do |post| 
        outstr "  #{colored_slug(post)}\n" 
        base = post.sub(/.lt3$/, "")
        num, rest = base[0..3], base[4..-1]
        puts "  ", fx(num, Red), fx(rest, Blue) unless testing
      end
    end
    puts unless testing
    @out
  end

  def cmd_list_drafts(arg, testing = false)
    reset_output
    drafts = @blog.drafts  # current view
    if drafts.empty?
      output! "No drafts"
      puts "\n  No drafts\n " unless testing
      return @out
    else
      puts unless testing
      drafts.each do |draft| 
        outstr "  #{colored_slug(draft.sub(/.lt3$/, ""))}\n" 
        base = draft.sub(/.lt3$/, "")
        num, rest = base[0..3], base[4..-1]
        puts "  ", fx(num, Red), fx(rest, Blue) unless testing
      end
    end
    puts unless testing
    @out
  end

  def cmd_list_assets(arg, testing = false)
    reset_output
    dir = @blog.view.dir + "/assets"
    assets = Dir[dir + "/*"]
    if assets.empty?
      output! "No assets"
      puts "  No assets" unless testing
      return @out
    else
      puts unless testing
      assets.each do |name| 
        asset = File.basename(name)
        outstr asset
        puts "  ", fx(asset, Blue) unless testing
      end
    end
    puts unless testing
    @out
  end

  def cmd_ssh(arg, testing = false)
    pub = @blog.view.publisher
    puts
    system!("tputs clear; ssh #{pub.user}@#{pub.server}")
    sleep 0.1
    cmd_clear(nil)
  end

  def cmd_INVALID(arg, testing = false)
    reset_output "\n  Command '#{arg}' was not understood."
    print fx("\n  Command ", :bold)
    print fx(arg, Red, :bold)
    puts fx(" was not understood.\n ", :bold)
    @out
  end

  def cmd_legacy(arg = nil)
#   dir = ask("Dir = ")
    dir = "sources/computing"
    puts "Importing from: #{dir}"
    files = Dir[dir/"**"]
    files.each do |fname|
      name = fname
      cmd = "grep ^.title #{name}"
      grep = `#{cmd}`   # find .title
      @title = grep.sub(/^.title /, "")
      num = `grep ^.post #{name}`.sub(/^.post /, "").to_i
      seq = @blog.get_sequence
      tnum = File.basename(fname).to_i

      raise "num != seq + 1" if num != seq + 1
      raise "num != tnum" if num != tnum
      seq = @blog.next_sequence
      raise "num != seq" if num != seq

      label = '%04d' % num
      slug0 = @title.downcase.strip.gsub(' ', '-').gsub(/[^\w-]/, '')
      @slug = "#{label}-#{slug0}"
      @fname = @slug + ".lt3"
      cmd = "cp #{name} #{@blog.root}/drafts/#@fname"
      result = system!(cmd)
      raise CantCopy(name, "#{@blog.root}/drafts/#@fname") unless result
      # post = Post.load(@slug)
      draft = "#{@blog.root}/drafts/#@fname"
      @meta = @blog.generate_post(draft)
      puts
      sleep 2
    end
  rescue => err
    error(err)
  end

  Help = <<-EOS

  {Basics:}                                         {Views:}
  -------------------------------------------       -------------------------------------------
  {h, help}           This message                  {change view VIEW}  Change current view
  {q, quit}           Exit the program              {cv VIEW}           Change current view
  {v, version}        Print version information     {new view}          Create a new view
  {clear}             Clear screen                  {list views}        List all views available
                                                    {lsv}               Same as: list views
                   

  {Posts:}                                          {Advanced:}
  -------------------------------------------       -------------------------------------------
  {p, post}           Create a new post             {config}            Edit various system files
  {new post}          Same as p, post               {customize}         (BUGGY) Change set of tags, extra views
  {lsp, list posts}   List posts in current view    {preview}           Look at current (local) view in browser
  {lsd, list drafts}  List all drafts (all views)   {browse}            Look at current (published) view in browser
  {delete ID [ID...]} Remove multiple posts         {rebuild}           Regenerate all posts and relink
  {undelete ID}       Undelete a post               {publish}           Publish (current view)
  {edit ID}           Edit a post                   {ssh}               Login to remote server
  {import ASSETS}     Import assets (images, etc.)  {manage WIDGET}     Manage content/layout of a widget
  EOS

  def cmd_help(arg, testing = false)
    reset_output 
    msg = Help
    output msg
    msg.each_line do |line|
      e = line.each_char
      first = true
      loop do
        s1 = ""
        c = e.next
        if c == "{"
          s2 = first ? "" : "  "
          first = false
          loop do 
            c = e.next
            break if c == "}"
            s2 << c
          end
          print fx(s2, :bold)
          s2 = ""
        else
          s1 << c
        end
        print s1
      end
    end
    puts unless testing
    @out
  end
end

