require 'helpers-blog'
# require 'runeblog'
require 'global'

class RuneBlog::Post

  attr_reader :num, :title, :date, :views, :num, :slug

  include RuneBlog::Helpers

  def self.files(num, root)
    files = Find.find(root).to_a
    result = files.grep(/#{prefix(num)}-/)
    result
  end
  
  def self.load(post)
    raise NoBlogAccessor if RuneBlog.blog.nil?
    # "post" is a slug
    pdir = RuneBlog.blog.view.dir + "/" + post
    verify(Dir.exist?(pdir) => "Directory #{pdir} not found")
    meta = nil
    Dir.chdir(pdir) do
      verify(File.exist?("metadata.txt") => "metadata.txt not found",
             File.exist?("teaser.txt") => "teaser.txt not found",
             File.exist?("body.txt") => "body.txt not found")
      meta = read_config("metadata.txt")
      verify(meta.date  => "meta.date is nil",
             meta.views => "meta.views is nil",
             meta.tags  => "meta.tags is nil")
      meta.date = Date.parse(meta.date)
      meta.views = meta.views.split
      meta.tags = meta.tags.split
      meta.teaser = File.read("teaser.txt")
      meta.body = File.read("body.txt")
    end
    meta
  end

  def create_post_subtree(viewname = nil) 
    # FIXME Doesn't really do anything - refactor
    debug "=== create_post_subtree #{viewname.inspect}  pwd = #{Dir.pwd}"
    # We are INSIDE views/myview/000n-mytitle dir now - FIXME later? how did that happen?
    create_dir("assets")
  end

  def write_metadata(meta)
    debug "=== write_metadata:"
    debug "-----\n#{meta.inspect}\n-----"
    fname2 = "metadata.txt"
    hash = meta.to_h

    File.write("teaser.txt", hash[:teaser])
    File.write("body.txt", hash[:body])
    hash.delete(:teaser)
    hash.delete(:body)

    hash[:views] = hash[:views].join(" ")
    hash[:tags]  = hash[:tags].join(" ")

    fields = [:num, :title, :date, :pubdate, :views, :tags]

    f2 = File.new(fname2, "w")
    fields.each {|fld| f2.puts "#{fld}: #{hash[fld]}" }
    f2.close
  end

  def initialize
    @blog = RuneBlog.blog || raise(NoBlogAccessor)
  end

  def self.create(title, teaser = "", body = "")
    debug "=== Post.create #{title.inspect}   pwd = #{Dir.pwd}"
    post = self.new
    post.new_metadata(title.chomp, teaser.chomp, body.chomp)
    post.create_draft
    post.create_post_subtree
    # post.build is not called here! It is called
    # in runeblog.rb:create_new_post AFTER post.edit
    post
  end

  def new_metadata(title, teaser = nil, body = nil)
    verify(title.is_a?(String) => "Title #{title.inspect} is not a string")
    meta = OpenStruct.new
    meta.title = title
    meta.teaser ||= teaser
    meta.body   ||= body
    meta.pubdate = Time.now.strftime("%Y-%m-%d")
    meta.date = meta.pubdate  # fix later
    meta.views = [@blog.view.to_s]
    meta.tags = []
    # ONLY place next_sequence is called!
    meta.num   = @blog.next_sequence
    @blog.make_slug(meta)  # adds to meta
    @meta = meta
  end

  def create_draft
# FIXME obsolete
# STDERR.puts "-- create_draft: teaser = #{@meta.teaser.inspect} body = #{@meta.body.inspect}"
    viewhome = @blog.view.publisher.url
    html = RuneBlog.post_template(title: @meta.title, date: @meta.pubdate, 
               view: @meta.view, teaser: @meta.teaser, body: @meta.body,
               views: @meta.views, tags: @meta.tags, home: viewhome)
    srcdir = "#{@blog.root}/drafts/"
    verify(Dir.exist?(srcdir) => "#{srcdir} not found",
           @meta.slug.is_a?(String) => "slug #{@meta.slug.inspect} is invalid")
    fname  = @meta.slug + ".lt3"
    @draft = srcdir + fname
    dump(html, @draft)
  end

  def edit
    verify(File.exist?(@draft) => "File #{@draft} not found")
    result = system("vi #@draft +8")  # TODO improve this
    raise EditorProblem(draft) unless result
    nil
  rescue => err
    error(err)
  end 

  def build
    debug "=== build"
    views = @meta.views
    text = File.read(@draft)
# STDERR.puts "-- build: draft = #{@draft.inspect}"
    livetext = Livetext.new(STDOUT)
    Livetext.parameters = [@blog, @meta.num, livetext]
    meta = livetext.process_text(text)
    raise RuneBlog::LivetextError(@draft) if meta.nil?

    meta.num = File.basename(@draft).to_i
    # FIXME what if title changes? slug should change?
    meta.views = views  # FIXME

    meta.views.each do |view_name|   
      # Create dir using slug (index.html, metadata?)
      vdir = "#{@blog.root}/views/#{view_name}/"
      dir = vdir + meta.slug + "/"
      create_dir(dir) unless Dir.exist?(dir)
      Dir.chdir(dir) do
        create_post_subtree(view_name)  # unless existing??
        system("cp body.txt index.html")
        @blog.generate_index(view_name)
      end
    end
    meta
  rescue => err
    p err
    puts err.backtrace.join("\n")
  end

end
