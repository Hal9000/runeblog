require 'find'
require 'livetext'

require 'runeblog_version'
require 'global'
require 'helpers-blog'
require 'default'
require 'view'
require 'publish'
require 'post'

###

class RuneBlog
 
  DotDir     = ".blogs"
  ConfigFile = "#{DotDir}/config"
  GemData    = RuneBlog::Path + "/../data"

  make_exception(:FileNotFound,      "File $1 was not found")
  make_exception(:BlogRepoAlreadyExists, "Blog repo $1 already exists")
  make_exception(:CantAssignView,    "$1 is not a view")
  make_exception(:ViewAlreadyExists, "View $1 already exists")
  make_exception(:DirAlreadyExists,  "Directory $1 already exists")
  make_exception(:CantCreateDir,     "Can't create directory $1")
  make_exception(:EditorProblem,     "Could not edit $1")
  make_exception(:NoSuchView,        "No such view: $1")
  make_exception(:LivetextError,     "Livetext#process_file returned nil for $1")
  
  class << self
    attr_accessor :blog
    include Helpers
  end

  attr_reader :root, :views, :sequence, :editor
  attr_accessor :view  # overridden

  attr_accessor :post_views, :post_tags, :dirty_views

  include Helpers

=begin
  timestamps
	  filename (cf with real file)
		
	themes
	  standard
		  head.lt3
	  	meta.lt3
    	global.lt3
	  	assets/
	  	blog/
			  [kill assets?]
				sidebar/
				  ad.lt3
					calendar.lt3
					news.lt3
					tag_cloud.lt3
				_postentry
				generate.lt3
				index.lt3
				meta.lt3
				navbar.lt3
	  	post/
			  generate.lt3
				head.lt3
				index.lt3
=end

  def self.create_new_blog_repo(first_view, dir = ".blogs/data")
    raise ArgumentError unless dir.is_a?(String) && ! dir.empty?
    root_dir = Dir.pwd + "/" + dir
    raise BlogRepoAlreadyExists if Dir.exist?(root_dir)
    new_dotfile(root: root_dir, current_view: first_view)
    create_dir(dir)
# New code goes here! 
    Dir.chdir(dir) do
      create_dir("drafts")
      create_dir("views")
#???  create_dir("generated")
#?    create_dir("assets")
      new_sequence
    end
    blog = self.new
    blog.create_view(first_view)
  rescue => err
    puts "Can't create blog repo: '#{dir}' - #{err}"
    puts err.backtrace.join("\n")
  end

  def initialize   # assumes existing blog
    # Crude - FIXME later - 
    # What views are there? Publishing, etc.
    self.class.blog = self   # Weird. Like a singleton - dumbass circular dependency?
    @root, @view_name, @editor = 
      read_config(ConfigFile, :root, :current_view, :editor)
    @views = get_views
    @view = str2view(@view_name)
    @sequence = get_sequence
    @post_views = []
    @post_tags = []
  end

  def view?(name)
    raise ArgumentError unless name.is_a?(String) && ! name.empty?
    views.any? {|x| x.name == name }
  end

  def view(name = nil)
    raise ArgumentError unless name.nil? || (name.is_a?(String) && ! name.empty?)
    name.nil? ? @view : str2view(name)
  end

  def str2view(str)
    raise ArgumentError unless str.is_a?(String) && ! str.empty?
    @views.find {|x| x.name == str }
  end

  def view=(arg)
    case arg
      when RuneBlog::View
        @view = arg
        @view.publisher = RuneBlog::Publishing.new(read_config(@view.dir + "/publish"))
      when String
        new_view = str2view(arg)
        raise NoSuchView(arg) if new_view.nil?
        @view = new_view
        @view.publisher = RuneBlog::Publishing.new(read_config(@view.dir + "/publish"))
      else 
        raise CantAssignView(arg.class.to_s)
    end
  end

  def get_sequence
    File.read(root + "/sequence").to_i
  end

  def next_sequence
    @sequence += 1
    dump(@sequence, "#@root/sequence")
    @sequence
  end

  def viewdir(v = nil)
    v = str2view(v) if v.is_a?(String)
    raise ArgumentError unless v.nil? || v.is_a?(RuneBlog::View)
    v ||= @view
    @root + "/views/#{v}/"
  end

  def self.exist?
    Dir.exist?(DotDir) && File.exist?(ConfigFile)
  end

  def create_view(arg)
    debug "=== create_view #{arg.inspect}"
    raise ArgumentError unless arg.is_a?(String) && ! arg.empty?

    names = self.views.map(&:to_s)
    raise ViewAlreadyExists(arg) if names.include?(arg)

    vdir = "#@root/views/#{arg}/"
    raise DirAlreadyExists(vdir) if Dir.exist?(vdir)
    create_dir(vdir)
    up = Dir.pwd

    Dir.chdir(vdir)
    x = RuneBlog::Default
    create_dir('themes')
#   create_dir("local")
    create_dir("generated")
    create_dir("generated/blog")
    create_dir('assets')

    Dir.chdir("themes") { system("tar zxvf #{GemData}/standard.tgz 2>/dev/null") }
    pub = "user: xxx\nserver: xxx\ndocroot: xxx\npath: xxx\nproto: xxx\n"
    dump(pub, "publish")

    view = RuneBlog::View.new(arg)
    self.view = view
    vdir = self.view.dir
    dir0 = "#{vdir}/themes/standard/blog"
    dir1 = "#{vdir}/generated/blog"
    system("livetext #{dir0}/generate.lt3 >#{dir1}/index.html 2>#{dir1}/index.err")
    dump("Initial creation", "last_published")
    Dir.chdir(up)
    @views << view
    @views
  end

  def delete_view(name, force = false)
    raise ArgumentError unless name.is_a?(String) && ! name.empty?
    if force
      system("rm -rf #@root/views/#{name}") 
      @views -= [str2view(name)]
    end
  end

  def view_files
    vdir = self.viewdir
    files = ["#{vdir}/index.html"]
    files += posts.map {|x| "#{vdir}/#{x}" }
    # Huh? 
    files.reject! {|f| File.mtime(f) < File.mtime("#{vdir}/last_published") }
  end

  def files_by_id(id)   # FIXME get rid of this later
    raise ArgumentError unless id.is_a?(Integer)
    files = Find.find(self.view.dir).to_a
    tag = prefix(id)
    result = files.grep(/#{tag}-/)
    result
  end

  def create_new_post(title, testing = false)
    save = Dir.pwd
    Dir.chdir(self.view.dir)
    post = Post.create(title)
    post.edit unless testing
    meta = post.build
    Dir.chdir(save)
    meta.num
  rescue => err
    puts err
    puts err.backtrace.join("\n")
  end

  def edit_initial_post(file, testing = false)
    debug "=== edit_initial_post #{file.inspect}  => #{sourcefile}"
    sourcefile = "#@root/drafts/#{file}"
    result = system("#@editor #{sourcefile} +8") unless testing
    raise EditorProblem(sourcefile) unless result
    nil
  rescue => err
    error(err)
  end

  def posts
    dir = self.view.dir
    posts = Dir.entries(dir).grep(/^\d{4}/)
    posts
  end

  def drafts
    dir = "#@root/drafts"
    drafts = Dir.entries(dir).grep(/^\d{4}.*/)
  end

  def change_view(view)
    raise ArgumentError unless view.is_a?(String) || view.is_a?(RuneBlog::View)
    x = OpenStruct.new
    x.root, x.current_view, x.editor = @root, view.to_s, @editor   # dumb - FIXME later
    write_config(x, ConfigFile)
    self.view = view   # error checking?
  end

  def process_post(file)
#   puts "    process_post #{file.inspect}   pwd = #{Dir.pwd}"
    debug "=== process_post #{file.inspect}   pwd = #{Dir.pwd}"
    raise ArgumentError unless file.is_a?(String)
    path = @root + "/drafts/#{file}"
    raise FileNotFound(path) unless File.exist?(path)
    num = file.to_i       # e.g. 0098-this-is-a-title
    live = Livetext.new # (STDOUT) # (nil)
    Livetext.parameters = [self, num, live]
    text = File.read(path)
    live.process_text(text)
  rescue => err
    error(err)
    getch
  end

  def generate_index(view)
    debug "=== generate_index view = #{view.to_s}"
    raise ArgumentError unless view.is_a?(String) || view.is_a?(RuneBlog::View)

    vdir = self.view.dir
    dir0 = "#{vdir}/themes/standard/blog"
    dir1 = "#{vdir}/generated/blog"
    system("livetext #{dir0}/generate.lt3 >#{dir1}/index.html 2>#{dir1}/index.err")
  rescue => err
    error(err)
    exit
  end

  def relink
    self.views.each {|view| generate_index(view) }
  end

  def index_entry(view, meta)
    debug "=== index_entry #{view.to_s.inspect}  #{meta.num} #{meta.title.inspect}"
    check_meta(meta, "index_entry1")
    raise ArgumentError unless view.is_a?(String) || view.is_a?(RuneBlog::View)
    check_meta(meta, "index_entry2")
    self.make_slug(meta)    # RuneBlog#index_entry
    check_meta(meta, "index_entry3")
    # FIXME clean up and generalize
    ref = "#{view}/#{meta.slug}/index.html"
    <<-HTML
      <font size=-1>#{meta.date}&nbsp;&nbsp;</font> <br>
      <font size=+2 color=blue><a href=../#{ref} style="text-decoration: none">#{meta.title}</font></a>
      <br>
      <font size=+1>#{meta.teaser}&nbsp;&nbsp;</font>
      <a href=../#{ref} style="text-decoration: none">Read more...</a>
      <br>
      <hr>
    HTML
  end

  def rebuild_post(file)
    debug "Called rebuild_post(#{file.inspect})"
    raise ArgumentError unless file.is_a?(String)
    meta = process_post(file)
# p meta
# sleep 4
    @views_dirty ||= []
    @views_dirty << meta.views
    @views_dirty.flatten!
    @views_dirty.uniq!
  rescue => err
    error(err)
    getch
  end

  def remove_post(num)
    raise ArgumentError unless num.is_a?(Integer)
    tag = prefix(num)
    files = Find.find(self.view.dir).to_a
    list = files.select {|x| File.directory?(x) and x =~ /#{tag}/ }
    return nil if list.empty?
    dest = list.map {|f| f.sub(/(?<num>\d{4}-)/, "_\\k<num>") }
    list.each.with_index do |src, i| 
      cmd = "mv #{src} #{dest[i]} 2>/dev/null"
      system(cmd)
    end
    # FIXME - update index/etc
    true
  end

  def undelete_post(num)
    raise ArgumentError unless num.is_a?(Integer)
    files = Find.find("#@root/views/").to_a
    tag = prefix(num)
    list = files.select {|x| File.directory?(x) and x =~ /_#{tag}/ }
    return nil if list.empty?
    dest = list.map {|f| f.sub(/_(?<num>\d{4}-)/, "\\k<num>") }
    list.each.with_index do |src, i| 
      cmd = "mv #{src} #{dest[i]} 2>/dev/null"
      system(cmd)
    end
    # FIXME - update index/etc
    true
  end

  def delete_draft(num)
    raise ArgumentError unless num.is_a?(Integer)
    tag = prefix(num)
    system("rm -rf #@root/drafts/#{tag}-*")
  end

  def post_exists?(num)
    raise ArgumentError unless num.is_a?(Integer)
    list = files_by_id(num)  # FIXME search under view dirs
    list.empty? ? nil : list
  end

  def make_slug(meta)
    check_meta(meta, "makeslug")
    raise ArgumentError unless meta.title.is_a?(String)
    label = '%04d' % meta.num   # FIXME can do better
    slug0 = meta.title.downcase.strip.gsub(' ', '-').gsub(/[^\w-]/, '')
    str = "#{label}-#{slug0}"
    meta.slug = str
    str
  end

end

