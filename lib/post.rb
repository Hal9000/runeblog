require 'helpers-blog'
require 'runeblog'

class RuneBlog::Post

  attr_reader :id, :title, :date, :views, :num, :slug

  def self.files(num, root)
    files = Find.find(root).to_a
    result = files.grep(/#{tag(num)}-/)
    result
  end
  
  def initialize(title, view_name, 
                 teaser = "Teaser goes here.",
                 remainder = "Remainder of post goes here.")
    raise "RuneBlog.blog is not set!" if RuneBlog.blog.nil?
    @blog = RuneBlog.blog
    @title = title
    @view = @blog.str2view(view_name)
    @num, @slug = make_slug
    date = Time.now.strftime("%Y-%m-%d")
    template = <<-EOS.gsub(/^ */, "")
      .mixin liveblog
 
      .title #{title}
      .pubdate #{date}
      .views #@view
 
      .teaser
      #{teaser}
      .end
      #{remainder}
    EOS
 
    @draft = "#{@blog.root}/src/#@slug.lt3"
    File.write(@draft, template)
  end

  def edit
    result = system("vi #@draft +8")
    raise "Problem editing #@draft" unless result
    nil
  rescue => err
    error(err)
  end 

  def publish
    livetext = Livetext.new(STDOUT)
    @meta = livetext.process_file(@draft, binding)
    raise "process_file returned nil" if @meta.nil?

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
    p err
    err.backtrace.each {|x| puts x }
    # error(err)
  end

  private

  def create_post_subtree(vdir)
    create_dir("assets") 
    File.write("metadata.yaml", @meta.to_yaml)
    template = File.read(vdir + "/custom/post_template.html")
    text = interpolate(template)
    File.write("index.html", text)
  end

  def make_slug(postnum = nil)
    postnum ||= @blog.next_sequence
    num = tag(postnum)   # FIXME can do better
    slug = @title.downcase.strip.gsub(' ', '-').gsub(/[^\w-]/, '')
    [postnum, "#{num}-#{slug}"]
  end

  def tag(num)
    "#{'%04d' % num}"
  end
end
