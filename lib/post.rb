require 'runeblog'
require 'pathmagic'

class RuneBlog::Post

  attr_reader :num, :title, :date, :views, :num, :slug
  attr_accessor :meta, :blog, :draft

  include RuneBlog::Helpers

  
  def self.load(post)
    log!(enter: __method__, args: [post], level: 3)
    raise NotImplemented
    raise NoBlogAccessor if RuneBlog.blog.nil?
    # "post" is a slug?
    pdir = RuneBlog.blog.root/:drafts/post
    meta = nil
    Dir.chdir(pdir) do
#     meta = read_config("metadata.txt")
#     meta.date = Date.parse(meta.date)
#     meta.views = meta.views.split
#     meta.tags = meta.tags.split
#     meta.teaser = File.read("teaser.txt")
#     meta.body = File.read("body.txt")
    end
    meta
  end

  def initialize
    log!(enter: __method__, level: 3)
    @blog = RuneBlog.blog || raise(NoBlogAccessor)
    @meta = OpenStruct.new
  end

  def self.create(title:, teaser:, body:, pubdate: Time.now.strftime("%Y-%m-%d"),
                  views:[], file: nil)
    log!(enter: __method__, args: [title, teaser, body, pubdate, views], stderr: true)
    post = self.new
    # NOTE: This is the ONLY place next_sequence is called!
    num = post.meta.num   = post.blog.next_sequence

    # new_metadata
    post.meta.title, post.meta.teaser, post.meta.body, post.meta.pubdate = 
      title, teaser, body, pubdate
    post.meta.views = [post.blog.view.to_s] + views
    post.meta.tags = []
    post.blog.make_slug(post.meta)  # adds to meta

    # create_draft
    viewhome = post.blog.view.publisher.url
    meta = post.meta
    if file.nil?
      text = RuneBlog.post_template(num: meta.num, title: meta.title, date: meta.pubdate, 
                 view: meta.view, teaser: meta.teaser, body: meta.body,
                 views: meta.views, tags: meta.tags, home: viewhome)
      srcdir = post.blog.root/:drafts + "/"
      vpdir = post.blog.root/:drafts + "/"
      fname  = meta.slug + ".lt3"
      post.draft = srcdir + fname
      dump(text, post.draft)
    else
      dump(File.read(file), post.draft)
    end
    return post
  end

  def edit
    log!(enter: __method__)
    edit_file(@draft, vim: "+8")
    build
  rescue => err
    error(err)
  end 

  def build
    log!(enter: __method__)
    post = self
    views = post.meta.views
    @blog.generate_post(@draft)
    @blog.generate_index(@blog.view)
  end
end

class RuneBlog::ViewPost
  attr_accessor :nslug, :aslug, :num, :view, :blog
  attr_accessor :path, :title, :date, :teaser_text

  def self.make(blog:, view:, nslug:)
    raise NoNumericPrefix(nslug) unless nslug =~ /^\d{4}-/
    raise NoExtensionExpected(nslug) if nslug.end_with?(".lt3") || nslug.end_with?(".html")
    view = view.to_s
    view.define_singleton_method :path do |subdir = ""|
      str = blog.root/:views/view
      str << "/#{subdir}" unless subdir.empty?
      str
    end
    view.define_singleton_method :standard do |subdir = ""|
      str = blog.root/:views/view/:themes/:standard
      str << "/#{subdir}" unless subdir.empty?
      str
    end
    view.define_singleton_method :postdir do |file = ""|
      file = file.to_s
      str = blog.root/:views/view/:posts/nslug
      str = str/file unless file.empty?
      str
    end 
    view.define_singleton_method :remote do |dir: "", file: ""|
      subdir = subdir.to_s
      file = file.to_s
      str = blog.root/:views/view/:remote
      str = str/subdir unless subdir.empty?
      str = str/file unless file.empty?
      str
    end
    obj = RuneBlog::ViewPost.new(view, nslug)
    obj.blog = blog
    obj.view = view
    obj.nslug = nslug
    obj.aslug = nslug[5..-1]
    obj.num = nslug[0..3]
    obj
  end

  def repo(subdir = "")
    subdir = subdir.to_s
    unless subdir.empty?
      raise "Expected 'posts' or 'drafts'" unless %w[posts drafts].include?(subdir)
    end
    str = blog.root
    str = str/subdir unless subdir.empty?
    str
  end

  alias root repo

  def slug(num = true, ext = "")
    ext = ext.to_s
    str = ""
    str << @num << "-" if num
    str << @aslug 
    str << ext
    str
  end
              
=begin
  aslug          this-is-a-post
  aslug_live     this-is-a-post.lt3
  aslug_html     this-is-a-post.lt3
  nslug          0001-this-is-a-post

  slug(:num, ext = "")
=end

  def initialize(view, postdir)
    log!(enter: __method__, args: [view, postdir], level: 3)
    # Assumes already parsed/processed
    @blog = RuneBlog.blog || raise(NoBlogAccessor)
    @path = postdir.dup
    @nslug = @path.split("/").last
    @aslug = @nslug[5..-1]
    fname = "#{postdir}/teaser.txt"            # ???
    @teaser_text = File.read(fname).chomp
    
    Dir.chdir(postdir) do 
      meta = @blog.read_metadata
      @title = meta.title
      @date  = meta.pubdate
    end
  rescue => err
    STDERR.puts "--- #{err}"
    STDERR.puts "    #{err.backtrace.join("\n  ")}" if err.respond_to?(:backtrace)
  end

  def get_dirs
    log!(enter: __method__, args: [view, postdir], level: 3)
    fname = File.basename(draft)
    noext = fname.sub(/.lt3$/, "")
    vdir = @root/:views/view
    dir = vdir/:posts/noext + "/"
    Dir.mkdir(dir) unless Dir.exist?(dir)
    system!("cp #{draft} #{dir}")
    viewdir, slugdir, aslug = vdir, dir, noext[5..-1]
    theme = viewdir/:themes/:standard
    [noext, viewdir, slugdir, aslug, theme]
  end

end

