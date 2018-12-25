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

  def initialize(meta, view_name)
    # FIXME weird logic here
    @blog = RuneBlog.blog || raise(NoBlogAccessor)
    @blog.make_slug(meta)  # Post#initialize
    meta.pubdate = Time.now.strftime("%Y-%m-%d")
    meta.date = meta.pubdate  # fix later
    meta.views = [view_name]
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

  def build(meta=nil)
    meta = @meta  # FIXME
    check_meta(meta, "Post.build")
    livetext = Livetext.new(STDOUT)
  puts "build: meta = #{meta.inspect}"
    views = meta.views
    @meta2 = livetext.process_file(@draft, binding)
    @meta2.num = meta.num  # dumb?
    @meta2.views = views   # extra dumb
    check_meta(@meta2, "build2")
    raise LivetextError(@draft) if @meta2.nil?

  puts "build: cp 2 - meta2 = #{@meta2.inspect}"

    # Hmm. @meta2 differs from meta -- views, etc.

    # FIXME what if title changes?

    @meta2.views.each do |view_name|   # Create dir using slug (index.html, metadata?)
  puts "build: cp 3 - view = #{view_name}"
      view = @blog.str2view(view_name)
      vdir = view.dir
      dir = vdir + meta.slug + "/"
      Dir.mkdir(dir)
      Dir.chdir(dir) do
  puts "build: cp 4 - view = #{view_name}"
        create_post_subtree(vdir)
  puts "build: cp 5 - view = #{view_name}"
        @blog.generate_index(view)
  puts "build: cp 6 - view = #{view_name}"
      end
    end
  rescue => err
    p err
    puts err.backtrace.join("\n")
  end

  private

  def create_post_subtree(vdir)
    create_dir("assets") 
    check_meta(@meta2, "create_post_subtree")
    write_metadata(@meta2)
    meta = @meta2
    text = RuneBlog.teaser_template(title: meta.title, date: meta.date, 
                                    view: meta.view, teaser: meta.teaser, 
                                    body: meta.body)
    dump(text, "index.html")   # FIXME write_index ?
  end

  def write_metadata(meta)
    fname2 = "metadata.txt"
    hash = meta.to_h
debug "write_meta: #{hash.inspect}"
    
    File.write("teaser.txt", hash[:teaser])
    File.write("body.txt", hash[:body])
    hash.delete(:teaser)
    hash.delete(:body)
    
    hash[:views] = hash[:views].join(" ")
    hash[:tags]  = hash[:tags].join(" ")
    
    fields = [:num, :title, :date, :pubdate, :views, :tags]
    
    f2 = File.new(fname2, "w")
    fields.each do |fld|
      f2.puts "#{fld}: #{hash[fld]}"
    end
    f2.close
  end

end
