require 'helpers-blog'
require 'runeblog'

make_exception(:NoBlogAccessor, "Runeblog.blog is not set")

class RuneBlog::Post

  attr_reader :id, :title, :date, :views, :num, :slug

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
    end
    meta
  end

  def initialize(meta, view_name)
    # FIXME weird logic here
    raise NoBlogAccessor if RuneBlog.blog.nil?
    @blog = RuneBlog.blog
    @title = meta.title
    @view = @blog.str2view(view_name)
    @num, @slug = make_slug
    @date = Time.now.strftime("%Y-%m-%d")
    template = RuneBlog::Default::PostTemplate
    @meta = meta
    html = interpolate(template)
    @draft = "#{@blog.root}/src/#@slug.lt3"
    dump(html, @draft)
  end

  def edit
    result = system("vi #@draft +8")
    raise EditorProblem(draft) unless result
    nil
  rescue => err
    error(err)
  end 

  def build
    livetext = Livetext.new(STDOUT)
    @meta = livetext.process_file(@draft, binding)
    raise LivetextError(@draft) if @meta.nil?

    @meta.views.each do |view_name|   # Create dir using slug (index.html, metadata?)
      view = @blog.str2view(view_name)
      vdir = view.dir
      dir = vdir + @slug + "/"
      Dir.mkdir(dir)
      Dir.chdir(dir) do
        create_post_subtree(vdir)
        @blog.generate_index(view)
      end
    end
  rescue => err
    p err  # CHANGE_FOR_CURSES?
    puts err.backtrace  # CHANGE_FOR_CURSES?
  end

  private

  def create_post_subtree(vdir)
    create_dir("assets") 
    write_metadata(@meta)
    template = RuneBlog::Default::TeaserTemplate   # FIXME template into custom dir?
    text = interpolate(template)
    dump(text, "index.html")   # FIXME write_index ?
  end

  def make_slug(postnum = nil)
    postnum ||= @blog.next_sequence
    num = prefix(postnum)   # FIXME can do better
    slug = @title.downcase.strip.gsub(' ', '-').gsub(/[^\w-]/, '')
    [postnum, "#{num}-#{slug}"]
  end

  def write_metadata(meta)
    fname2 = "metadata.txt"
    hash = meta.to_h
    
    File.write("teaser.txt", hash[:teaser])
    File.write("body.txt", hash[:body])
    hash.delete(:teaser)
    hash.delete(:body)
    
    hash[:views] = hash[:views].join(" ")
    hash[:tags]  = hash[:tags].join(" ")
    
    fields = [:title, :date, :pubdate, :views, :tags]
    
    f2 = File.new(fname2, "w")
    fields.each do |fld|
      f2.puts "#{fld}: #{hash[fld]}"
    end
    f2.close
  end

end
