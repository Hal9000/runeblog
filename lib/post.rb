require 'helpers-blog'
require 'runeblog'

make_exception(:NoBlogAccessor, "Runeblog.blog is not set")

class RuneBlog::Post

  attr_reader :num, :title, :date, :views, :num, :slug

  include RuneBlog::Helpers

  def self.files(num, root)
    files = Find.find(root).to_a
    result = files.grep(/#{prefix(num)}-/)
    result
  end
  
  def self.load(post)
    # FIXME weird logic here
    raise NoBlogAccessor if RuneBlog.blog.nil?
    pdir = RuneBlog.blog.view.dir + "/" + post
    meta = nil
    Dir.chdir(pdir) do
      meta = read_config("metadata.txt")
      meta.date = Date.parse(meta.date)
      meta.views = meta.views.split
      meta.tags = meta.tags.split
      meta.teaser = File.read("teaser.txt")
      meta.body = File.read("body.txt")
      check_meta(meta, "Post.load")
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
    debug "=== Post#initialize"
    @blog = RuneBlog.blog || raise(NoBlogAccessor)
  end

  def self.create(title)
    debug "=== Post.create #{title.inspect}   pwd = #{Dir.pwd}"
    post = self.new
    post.new_metadata(title)
    post.create_draft
    post.create_post_subtree  # gets done in build anyway
#   post.build   # where livetext gets called
    post
  end

  def new_metadata(title)
    meta = OpenStruct.new
    meta.title = title
    meta.teaser = "Teaser goes here."
    meta.body   = "Remainder of post goes here."
    meta.pubdate = Time.now.strftime("%Y-%m-%d")
    meta.date = meta.pubdate  # fix later
    meta.views = [@blog.view.to_s]
    # only place next_sequence is called
    meta.num   = @blog.next_sequence
    @blog.make_slug(meta)  # adds to meta
    @meta = meta
  end

  def create_draft
    html = RuneBlog.post_template(title: @meta.title, date: @meta.pubdate, 
               view: @meta.view, teaser: @meta.teaser, body: @meta.body)
    @draft = "#{@blog.root}/src/#{@meta.slug}.lt3"
    dump(html, @draft)
  end

  def old_initialize(meta, view_name)
    # FIXME weird logic here
    @blog = RuneBlog.blog || raise(NoBlogAccessor)
    @blog.make_slug(meta)  # Post#initialize
    check_meta(meta, "Post#initialize")
    html = RuneBlog.post_template(title: meta.title, date: meta.pubdate, 
                                  view: meta.view, teaser: meta.teaser, 
                                  body: meta.body)
    slug = meta.slug
    @meta = meta
    @draft = "#{@blog.root}/src/#{slug}.lt3"
    dump(html, @draft)
  rescue => err
    puts err
    puts err.backtrace
  end

  def edit
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
    Livetext.parameters = [@blog, @meta]
    livetext = Livetext.new(STDOUT)
    meta = livetext.process_text(text)
    raise LivetextError(@draft) if meta.nil?

    meta.num = File.basename(@draft).to_i
    # FIXME what if title changes? slug should change?
    meta.views = views  # FIXME

    meta.views.each do |view_name|   # Create dir using slug (index.html, metadata?)
      vdir = "#{@blog.root}/views/#{view_name}/"
      dir = vdir + meta.slug + "/"
      create_dir(dir) unless Dir.exist?(dir)
      Dir.chdir(dir) do
        create_post_subtree(view_name)  # unless existing??
        @blog.generate_index(view_name)
      end
    end
    meta
  rescue => err
    p err
    puts err.backtrace.join("\n")
  end

end
