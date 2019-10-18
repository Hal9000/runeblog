require 'runeblog'
require 'global'
require 'pathmagic'

class RuneBlog::Post

  attr_reader :num, :title, :date, :views, :num, :slug
  attr_accessor :meta, :blog, :draft

  include RuneBlog::Helpers

  def self.files(num, root)
    log!(enter: __method__, args: [num, root], level: 3)
    files = ::Find.find(root).to_a
    result = files.grep(/#{prefix(num)}-/)
    result
  end
  
  def self.load(post)
    log!(enter: __method__, args: [post], level: 3)
    raise "Doesn't work right now"
    raise NoBlogAccessor if RuneBlog.blog.nil?
    # "post" is a slug
    pdir = RuneBlog.blog.view.dir/post
    meta = nil
    Dir.chdir(pdir) do
      meta = read_config("metadata.txt")
      meta.date = Date.parse(meta.date)
      meta.views = meta.views.split
      meta.tags = meta.tags.split
      meta.teaser = File.read("teaser.txt")
#     meta.body = File.read("body.txt")
    end
    meta
  end

  def write_metadata(meta)   # FIXME ???
    log!(enter: __method__, args: [meta], level: 3)
    debug "=== write_metadata:"
    debug "-----\n#{meta.inspect}\n-----"
    fname2 = "metadata.txt"
    hash = meta.to_h

    File.write("teaser.txt", hash[:teaser])
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
    log!(enter: __method__, level: 3)
    @blog = RuneBlog.blog || raise(NoBlogAccessor)
    @meta = OpenStruct.new
  end

  def self.create(title:, teaser:, body:, pubdate: Time.now.strftime("%Y-%m-%d"),
                  views:[])
    log!(enter: __method__, args: [title, teaser, body, pubdate, views])
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
    text = RuneBlog.post_template(num: meta.num, title: meta.title, date: meta.pubdate, 
               view: meta.view, teaser: meta.teaser, body: meta.body,
               views: meta.views, tags: meta.tags, home: viewhome)
    srcdir = post.blog.root/:drafts + "/"
    vpdir = post.blog.root/:drafts + "/"
    fname  = meta.slug + ".lt3"
    post.draft = srcdir + fname
    dump(text, post.draft)
    return post
  end

  def edit
    log!(enter: __method__)
    result = system!("vi #@draft +8")  # TODO improve this
    raise EditorProblem(draft) unless result
    nil
  rescue => err
    error(err)
  end 

  def build
    log!(enter: __method__)
    post = self
    views = post.meta.views
    text = File.read(@draft)
    @blog.generate_post(@draft)
  end
end

class RuneBlog::ViewPost
  attr_reader :path, :nslug, :aslug, :title, :date,
              :teaser_text
              
  def initialize(view, postdir)
    log!(enter: __method__, args: [view, postdir], level: 3)
    # Assumes already parsed/processed
    @blog = RuneBlog.blog || raise(NoBlogAccessor)
    @path = postdir.dup
    @nslug = @path.split("/").last
    @aslug = @nslug[5..-1]
    fname = "#{postdir}/teaser.txt"
    @teaser_text = File.read(fname).chomp
    # FIXME dumb hacks...
    mdfile = postdir/"metadata.txt"
    lines = File.readlines(mdfile)
    @title = lines.grep(/title:/).first[7..-1].chomp
    @date  = lines.grep(/pubdate:/).first[9..-1].chomp
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

