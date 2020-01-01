require 'runeblog'
require 'ostruct'
require 'helpers-repl'  # FIXME structure
require 'pathmagic'

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
    cmd_clear
  end

  def cmd_quit
    STDSCR.rows.times { puts " "*(STDSCR.cols-1) }
    # FIXME please?
    sleep 0.1
    STDSCR.clear
    sleep 0.1
    RubyText.stop
    sleep 0.1
    system("clear")
    sleep 0.1
    exit
  end

  def cmd_clear
    STDSCR.rows.times { puts " "*(STDSCR.cols-1) }
    sleep 0.1
    STDSCR.clear
  end

  def cmd_version
    puts fx("\n  RuneBlog", :bold), fx(" v #{RuneBlog::VERSION}\n", Red)
  end

  def cmd_config
    hash = {"Global configuration"                     => "global.lt3",
            "   View-specific variables"               => "../../settings/view.txt",
            "   Recent posts"                          => "../../settings/recent.txt",
            "   Publishing vars"                       => "../../settings/publish.txt",
            "   Config for reddit"                     => "../../config/reddit/credentials.txt",
            "   Config for Facebook"                   => "../../config/facebook/credentials.txt",
            "   Config for Twitter"                    => "../../config/twitter/credentials.txt",
            "View generator"                           => "blog/generate.lt3",
            "   Banner: Description"                   => "blog/banner.lt3",
            "   Banner: Text portion"                  => "banner/top.lt3",
            "   HEAD info for view"                    => "blog/head.lt3",
            "   User-edited detail for view"           => "blog/index.lt3",
            "   Generator for recent-posts entry"      => "blog/post_entry.lt3",
            "Generator for a post"                     => "post/generate.lt3",
            "   HEAD info for post"                    => "post/head.lt3",
            "   Content for post"                      => "post/index.lt3",
            "Global CSS"                               => "etc/blog.css.lt3",
            "External JS/CSS (Bootstrap, etc.)"        => "/etc/externals.lt3"
           }

    dir = @blog.view.dir/"themes/standard/"
    num, target = STDSCR.menu(title: "Edit file:", items: hash)
    edit_file(dir/target)
  end

  def cmd_manage(arg)
    case arg
      when "pages";   _manage_pages(nil)
      when "links";   _manage_links(nil)
      when "navbar";  _manage_navbar(nil)
#     when "pinned";  _manage_pinned(nil)  # ditch this??
    else
      puts "#{arg} is unknown"
    end
  end

  def _manage_pinned   # cloned from manage_links
    dir = @blog.view.dir/"themes/standard/widgets/pinned"
    data = dir/"list.data"
    edit_file(data)
  end

  def _manage_navbar   # cloned from manage_pages
    dir = @blog.view.dir/"themes/standard/banner/navbar"
    files = Dir.entries(dir) - %w[. .. navbar.lt3]
    main_file = "[ navbar.lt3 ]"
    new_item  = "  [New item]  "
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

  def _manage_links
    dir = @blog.view.dir/"themes/standard/widgets/links"
    data = dir/"list.data"
    edit_file(data)
  end

  def _manage_pages(arg)
    dir = @blog.view.dir/"themes/standard/widgets/pages"
    # Assume child files already generated (and list.data??)
    data = dir/"list.data"
    lines = _get_data?(data)
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

  def cmd_import
    files = ask("\n  File(s) = ")
    system!("cp #{files} #{@blog.root}/views/#{@blog.view.name}/assets/")
  end

  def cmd_browse
    url = @blog.view.publisher.url
    if url.nil?   
      puts "\n  Publish first."
      return
    end
    result = system!("open '#{url}'")
    raise CantOpen(url) unless result
    return
  end

  def cmd_preview
    local = @blog.view.local_index
    unless File.exist?(local)
      puts "\n  No index. Rebuilding..."
      cmd_rebuild
    end
    result = system!("open #{local}")
    raise CantOpen(local) unless result
  rescue => err
    _tmp_error(err)
  end

  def cmd_publish
# Future Hal says please refactor this
    puts
    unless @blog.view.can_publish?
      msg = "Can't publish... see global.lt3"
      puts msg
      return
    end

    ret = RubyText.spinner(label: " Publishing... ") do
      @blog.view.publisher.publish
    end
    return unless ret

    vdir = @blog.view.dir
    dump("fix this later", "#{vdir}/last_published")
    puts "  ...finished.\n " unless ret
  rescue => err
    _tmp_error(err)
  end

  def fresh?(src, dst)
    return false unless File.exist?(dst)
    File.mtime(src) <= File.mtime(dst)
  end

  def regen_posts
    drafts = @blog.drafts  # current view
    drafts.each do |draft|
      orig = @blog.root/:drafts/draft
      html = @blog.root/:posts/draft
      html.sub!(/.lt3$/, "/guts.html")
      next if fresh?(orig, html)
      puts "  Regenerating #{draft}"
      @blog.generate_post(orig)    # rebuild post
    end
    puts
  end

  def cmd_rebuild
    debug "Starting cmd_rebuild..."
    puts
    @blog.generate_view(@blog.view)
    @blog.generate_index(@blog.view)
    regen_posts
  rescue => err
    _tmp_error(err)
  end

  def cmd_change_view(arg)
    # Simplify this
    if arg.nil?
      viewnames = @blog.views.map {|x| x.name }
      n = viewnames.find_index(@blog.view.name)
      name = @blog.view.name
      # TODO: Add view description 
      k, name = STDSCR.menu(title: "Views", items: viewnames, curr: n)
      return if name.nil?
      @blog.view = name
      puts "\n  ", fx(name, :bold), "\n"
      return
    else
      if @blog.view?(arg)
        @blog.view = arg
        puts "\n  ", fx(arg, :bold), "\n"
      end
    end
  end

  def cmd_new_view(arg)
    if arg.nil?
      arg = ask(fx("\nFilename: ", :bold))
      puts
    end
    @blog.create_view(arg)
    text = File.read("#{@blog.root}/data/global.lt3")
    File.write("#{@blog.root}/views/#{@blog.view}/themes/standard/global.lt3", 
               text.gsub(/VIEW_NAME/, @blog.view.to_s))
    vim_params = '-c ":set hlsearch" -c ":hi Search ctermfg=2 ctermbg=6" +/"\(VIEW_.*\|SITE.*\)"'
    edit_file(@blog.view.dir/"themes/standard/global.lt3", vim: vim_params)
    @blog.change_view(arg)
  rescue ViewAlreadyExists
    puts 'Blog already exists'
  rescue => err
    _tmp_error(err)
  end

  def cmd_new_post
    if @blog.views.empty?
      puts "\n  Create a view before creating the first post!\n "
      return
    end
    title = ask("\nTitle: ")
    puts
    @blog.create_new_post(title)
  rescue => err
    _tmp_error(err)
  end

  def _remove_post(arg, testing=false)
    id = get_integer(arg)
    result = @blog.remove_post(id)
    puts "Post #{id} not found" if result.nil?
  end

  def cmd_remove_post(arg)
    args = arg.split
    args.each do |x| 
      # FIXME
      ret = _remove_post(x.to_i, false)
      puts ret
    end
  end

  def cmd_edit_post(arg)
    id = get_integer(arg)
    # Simplify this
    tag = "#{'%04d' % id}"
    files = ::Find.find(@blog.root/:drafts).to_a
    files = files.grep(/#{tag}-.*lt3/)
    files = files.map {|f| File.basename(f) }
    if files.size > 1
      msg = "Multiple files: #{files}"
      puts msg
      return [false, msg]
    end
    if files.empty?
      msg = "\n  Can't edit post #{id}"
      puts msg
      return [false, msg]
    end

    file = files.first
    draft = @blog.root/:drafts/file
    vim_params = '-c G'
    result = edit_file(draft)
    @blog.generate_post(draft)
  rescue => err
    _tmp_error(err)
  end

  def cmd_list_views
    puts
    @blog.views.each do |v| 
      v = v.to_s
      v = fx(v, :bold) if v == @blog.view.name
      # FIXME: next 3 lines are crufty as hell
      lines = File.readlines(@blog.root/"views/#{v}/settings/view.txt")
      lines = lines.select {|x| x =~ /^title / && x !~ /VIEW_/ }
      title = lines.first.split(" ", 2)[1]
      print "  ", ('%15s' % v)
      puts  "  ", fx(title, :black)
    end
    puts
  end

  def cmd_list_posts
    posts = @blog.posts  # current view
    str = @blog.view.name + ":\n"
    puts
    puts "  ", fx(str, :bold)
    if posts.empty?
      puts "  No posts"
    else
      posts.each do |post| 
        base = post.sub(/.lt3$/, "")
        num, rest = base[0..3], base[4..-1]
        puts "  ", fx(num, Red), fx(rest, Blue)
        draft = @blog.root/:drafts/post + ".lt3"
        other = @blog._get_views(draft) - [@blog.view.to_s]
        unless other.empty?
          print fx(" "*7 + "also in: ", :bold) 
          puts other.join(", ") 
        end
      end
    end
    puts
  end

  def cmd_list_drafts
    drafts = @blog.drafts  # current view
    if drafts.empty?
      puts "\n  No drafts\n "
      return
    else
      puts
      drafts.each do |draft| 
        base = draft.sub(/.lt3$/, "")
        num, rest = base[0..3], base[4..-1]
        puts "  ", fx(num, Red), fx(rest, Blue)
        other = @blog._get_views(@blog.root/:drafts/draft) - [@blog.view.to_s]
        unless other.empty?
          print fx(" "*7 + "also in: ", :bold) 
          puts other.join(", ") 
        end
      end
    end
    puts
  end

  def cmd_list_assets
    dir = @blog.view.dir + "/assets"
    assets = Dir[dir + "/*"]
    if assets.empty?
      puts "  No assets"
      return
    else
      puts
      assets.each do |name| 
        asset = File.basename(name)
        puts "  ", fx(asset, Blue)
      end
    end
    puts
  end

  def cmd_ssh
    pub = @blog.view.publisher
    puts
    system!("tputs clear; ssh #{pub.user}@#{pub.server}")
    sleep 0.1
    cmd_clear
  end

  def cmd_INVALID(arg)
    print fx("\n  Command ", :bold)
    print fx(arg, Red, :bold)
    puts fx(" was not understood.\n ", :bold)
  end

  def cmd_legacy
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
  {new post}          Same as p, post                
  {lsp, list posts}   List posts in current view    {preview}           Look at current (local) view in browser
  {lsd, list drafts}  List all drafts (all views)   {browse}            Look at current (published) view in browser
  {delete ID [ID...]} Remove multiple posts         {rebuild}           Regenerate all posts and relink
  {undelete ID}       Undelete a post               {publish}           Publish (current view)
  {edit ID}           Edit a post                   {ssh}               Login to remote server
  {import ASSETS}     Import assets (images, etc.)  {manage WIDGET}     Manage content/layout of a widget
  EOS

  def cmd_help
    msg = Help
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
    puts
  end
end
