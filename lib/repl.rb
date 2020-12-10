require 'runeblog'
require 'ostruct'
require 'helpers-repl'  # FIXME structure
require 'pathmagic'
require 'exceptions'

require 'menus'

Signal.trap("INT") { puts "Don't  :)" }

module RuneBlog::REPL
  def edit_file(file, vim: "")
    ed = @blog.editor
    params = vim if ed =~ /vim$/
    result = system!("#{@blog.editor} #{file} #{params}")
    raise EditorProblem(file) unless result
    cmd_clear
  end

  def cmd_quit
    STDSCR.rows.times { puts " "*(STDSCR.cols-1) }
    STDSCR.clear
    sleep 0.1
    RubyText.stop
    sleep 0.1
    system("clear")
    exit
  end

  def cmd_clear
    STDSCR.rows.times { puts " "*(STDSCR.cols-1) }
    # sleep 0.1
    STDSCR.clear
  end

  def cmd_version
    puts fx("\n  RuneBlog", :bold), fx(" v #{RuneBlog::VERSION}\n", Red)
  end

  def cmd_config
    hash = {"Variables (general)"                 => "global.lt3",
            "   View-specific"                    => "../../settings/view.txt",
            "   Recent posts"                     => "../../settings/recent.txt",
            "   Publishing"                       => "../../settings/publish.txt",
            "Configuration: enable/disable"       => "../../settings/features.txt",
            "   Reddit"                           => "../../config/reddit/credentials.txt",
            "   Facebook"                         => "../../config/facebook/credentials.txt",
            "   Twitter"                          => "../../config/twitter/credentials.txt",
            "View: generator"                     => "blog/generate.lt3",
            "   HEAD info"                        => "blog/head.lt3",
            "   Layout "                          => "blog/index.lt3",
            "   Recent-posts entry"               => "blog/post_entry.lt3",
            "   Banner: Description"              => "blog/banner.lt3",
            "      Text portion"                  => "banner/top.lt3",
            "Generator for a post"                => "post/generate.lt3",
            "   HEAD info for post"               => "post/head.lt3",
            "   Content for post"                 => "post/index.lt3",
            "Global CSS"                          => "etc/blog.css.lt3",
            "External JS/CSS (Bootstrap, etc.)"   => "/etc/externals.lt3"
           }

    dir = @blog.view.dir/"themes/standard/"
    num, target = STDSCR.menu(title: "Edit file:", items: hash)
    edit_file(dir/target)
  end

  def cmd_manage(arg)
    case arg
      when "pages";   _manage_pages
      when "links";   _manage_links
      when "navbar";  _manage_navbar
      when "pinned";  _manage_pinned  # ditch this??
    else
      puts "#{arg} is unknown"
    end
  end

  def _manage_pinned   # cloned from manage_links
    dir = @blog.view.dir/"widgets/pinned"
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
    dir = @blog.view.dir/"widgets/links"
    data = dir/"list.data"
    edit_file(data)
  end

  def _manage_pages    # FIXME move into widget code
    dir = @blog.view.dir/"widgets/pages"
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
    msg = err.to_s
    msg << "\n" << err.backtrace.join("\n") if err.respond_to?(:backtrace)
    puts msg
    log!(str: msg) 
  end

  def cmd_publish
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
log! str:  "===  Regenerating posts..." unless drafts.empty?
    drafts.each do |draft|
      orig = @blog.root/:drafts/draft
      postdir = @blog.root/:posts/draft.sub(/.lt3$/, "")
      content = postdir/"/guts.html"
      next if fresh?(orig, content)

log! str:  "=== Calling generate_post(#{orig})"
      @blog.generate_post(orig)    # rebuild post
      Dir.chdir(postdir) do
        meta = @blog.read_metadata
        num, title = meta.num, meta.title
        num = '%4d' % num.to_s
        puts "  ", fx(num, Red), "  ", fx(title, Black)
      end
    end
  end

  def cmd_rebuild
log! str:  "=== Starting cmd_rebuild..."
    puts
    regen_posts
log! str:  "===   Generating view..."
    @blog.generate_view(@blog.view)
log! str:  "===   Generating index..."
    @blog.generate_index(@blog.view)
log! str:  "===   ...finished!"
  rescue => err
    _tmp_error(err)
  end

  def cmd_change_view(arg = nil)
    if arg.nil?
      viewnames = {}
      @blog.views.each do |v| 
        name = v.to_s
        title = view2title(name)
        string = "#{'%-25s' % title}  #{name}"
        viewnames[string] = name
      end
      n = viewnames.values.find_index(@blog.view.name)
      name = @blog.view.name
      k, name = STDSCR.menu(title: "Views", items: viewnames, curr: n, wrap: true)
      return if name.nil?
log! str:  "cv Setting to #{name.inspect}"
      @blog.view = name
#     puts "\n  ", fx(name, :bold), "\n"
      return
    else
      if @blog.view?(arg)
        @blog.view = arg
        puts "\n  ", fx(arg, :bold), "\n"
      end
    end
  end

  # move to helpers
  def modify_view_global(view_name)
    gfile = "#{@blog.root}/views/#{view_name}/data/global.lt3"
    lines = File.readlines(gfile).map(&:chomp)
    vars = <<~EOF
      .variables
      View     #{view_name}
      ViewDir  #{@blog.root}/views/#{view_name}
      .end

    EOF
    # lines.insert(5, vars)
    text = lines.join("\n")
    File.write(gfile, text)
  end

  def modify_view_settings(name:, title:, subtitle:, domain:)
    vfile = "#{@blog.root}/views/#{name}/settings/view.txt"
    hash = {/VIEW_NAME/     => name,
            /VIEW_TITLE/    => title,
            /VIEW_SUBTITLE/ => subtitle,
            /VIEW_DOMAIN/   => domain}
    @blog.complete_file(vfile, nil, hash)
  end

  def cmd_new_view(arg)
    view_name = ask!("      Filename: ")
    @blog.create_view(view_name)   # call change_view??
    title     = ask!("      View title: ")
    subtitle  = ask!("      Subtitle  : ")
    domain    = ask!("      Domain    : ")
    modify_view_global(view_name)
    modify_view_settings(name: view_name, title: title, subtitle: subtitle,
                         domain: domain)
    @blog.change_view(view_name)
  end 

  def cmd_new_view_ORIG(arg)
    if arg.nil?
      arg = ask(fx("\nFilename: ", :bold))
      puts
    end
    @blog.create_view(arg)
    lines = File.read("#{@blog.root}/data/global.lt3")
    # File.write("#{@blog.root}/views/#{@blog.view}/themes/standard/global.lt3", 
    File.write("#{@blog.root}/views/#{@blog.view}/data/global.lt3", 
               text.gsub(/VIEW_NAME/, @blog.view.to_s))
    vim_params = '-c ":set hlsearch" -c ":hi Search ctermfg=2 ctermbg=6" +/"\(VIEW_.*\|SITE.*\)"'
    # edit_file(@blog.view.dir/"themes/standard/global.lt3", vim: vim_params)
    edit_file(@blog.view.dir/"data/global.lt3", vim: vim_params)
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
    draft = exactly_one(files, files.join("/"))
    result = edit_file(draft, vim: '-c$')
    @blog.generate_post(draft)
  rescue => err
    _tmp_error(err)
  end

  def view2title(name)  # FIXME: crufty as hell
    lines = File.readlines(@blog.root/"views/#{name}/settings/view.txt")
    lines.map!(&:chomp)
    lines = lines.select {|x| x =~ /^title / && x !~ /VIEW_/ }
    title = lines.first.split(" ", 2)[1]
  end

  def cmd_list_views
    puts
    @blog.views.each do |v| 
      v = v.to_s
      title = view2title(v)
      v = fx(v, :bold) if v == @blog.view.name
      print "  ", ('%15s' % v)
      puts  "  ", fx(title, Black)
    end
    puts
  end

  def cmd_list_posts
    posts = @blog.posts  # current view
    str = @blog.view.name + ":\n"
    puts
    if posts.empty?
      puts "  No posts"
    else
      posts.each do |post| 
        base = post.sub(/.lt3$/, "")
        dir = @blog.root/:posts/base
        meta = nil 
        Dir.chdir(dir) { meta = @blog.read_metadata }
        num, title = meta.num, meta.title
        num = '%4d' % num.to_s
        puts "  ", fx(num, Red), "  ", fx(title, Black)
        draft = @blog.root/:drafts/post + ".lt3"
        other = meta.views - [@blog.view.to_s]
        unless other.empty?
          print fx(" "*9 + "also in: ", :bold) 
          puts other.join(", ") 
        end
      end
    end
    puts
  end

  def cmd_list_drafts
    curr_drafts = @blog.drafts  # current view
    if curr_drafts.empty?
      puts "\n  No drafts\n "
      return
    else
      puts
      curr_drafts.each do |draft| 
        base = draft.sub(/.lt3$/, "")
        dir = @blog.root/:posts/base
        meta = nil 
        Dir.chdir(dir) { meta = @blog.read_metadata }
        num, title = meta.num, meta.title
        num = '%4d' % num.to_s
        puts "  ", fx(num, Red), "  ", fx(title, Black)
        other = @blog._get_views(@blog.root/:drafts/draft) - [@blog.view.to_s]
        unless other.empty?
          print fx(" "*9 + "also in: ", :bold) 
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
      draft = "#{@blog.root}/drafts/#@fname"
      @meta = @blog.generate_post(draft)
      puts
      sleep 2
    end
  rescue => err
    error(err)
  end

=begin
  {lsw, list widgets} List all known widgets
  {install WIDGET}    Install a widget
  {enable WIDGET}     Use widget in this view
  {disable WIDGET}    Don't use widget in this view
  {update WIDGET}     Update widget code (this view)
  {manage WIDGET}     Manage widget content/layout 
=end

  def cmd_list_widgets
    # find/list all available widgets
    puts "\n  STUB: #{__method__}\n "
  end

  def cmd_install_widget(arg)
    # install a widget (view? global?)
    puts "\n  STUB: #{__method__}\n "
  end

  def cmd_enable_widget(arg)
    write_features({arg.to_sym => "1"}, @blog.view)
    puts "\n  Enabled #{arg}\n "
  end

  def cmd_disable_widget(arg)
    write_features({arg.to_sym => "0"}, @blog.view)
    puts "\n  Disabled #{arg}\n "
  end

  def cmd_update_widget(arg)
    # update widget code
    puts "\n  STUB: #{__method__}\n "
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
  {import ASSETS}     Import assets (images, etc.)  


  {Widgets:}
  -------------------------------------------       
  {lsw, list widgets} List all known widgets
  {install WIDGET}    Install a widget
  {enable WIDGET}     Use widget in this view
  {disable WIDGET}    Don't use in this view
  {update WIDGET}     Update code (this view)
  {manage WIDGET}     Manage content/layout 

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
