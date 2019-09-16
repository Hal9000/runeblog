require 'runeblog_version'

# Home = Dir.pwd # unless Home

module RuneBlog::Helpers

  def copy(src, dst)
    system("cp #{src}  #{dst}")
  end

  def copy!(src, dst)
    system("cp -r #{src}  #{dst}")
  end

  def stale?(src, dst)
    return true unless File.exist?(dst)
    return true if File.mtime(src) > File.mtime(dst)
    return false
  end

  def livetext(src, dst)
    src << ".lt3" unless src.end_with?(".lt3")
    dst << ".html" unless dst.end_with?(".html")
    return unless stale?(src, dst)
    system("livetext #{src} >#{dst}")
  end

  def get_root
    if $_blog
      if $_blog.root
        puts "0. Returned: #{$_blog.root}/"
        return $_blog.root + "/"
      else
        puts "1. Returned: ./"
        return "./"
      end
    else
      puts "2. Returned: ./"
      return "./"
    end
  end

  def read_config(file, *syms)
# puts "dir   = #{Dir.pwd}"
    lines = File.readlines(file).map(&:chomp)
    obj = ::OpenStruct.new
    lines.each do |line|
      next if line == "\n" || line[0] == "#"
      key, val = line.split(/: +/, 2)
      obj.send(key+"=", val)
    end
    return obj if syms.empty?

    vals = []
    if syms.empty?
      vals = obj.to_hash.values
    else
      syms.each {|sym| vals << obj.send(sym) }
    end
    return vals
  rescue => err
    puts "Can't read config file '#{file}': #{err}"
    puts err.backtrace.join("\n")
    puts "dir = #{Dir.pwd}"
    exit
  end

  def try_read_config(file, hash)
    return hash.values unless File.exist?(file)
    vals = read_config(file, *hash.keys)
# STDERR.puts vals.inspect
    vals
  end

def put_config(root:, view:"test_view", editor: "/usr/local/bin/vim")
  Dir.mkdir(root) unless Dir.exist?(root)
  Dir.chdir(root) do 
    File.open("config", "w") do |cfg|
      cfg.puts "root: #{root}"
      cfg.puts "current_view: #{view}"
      cfg.puts "editor: #{editor}"
    end
  end
end 

  def write_config(obj, file)
    hash = obj.to_h
# Dir.chdir(::Home)
# puts "--- wc: pwd = #{Dir.pwd}"
    File.open(file, "w") do |f| 
      hash.each_pair do |key, val|
        f.puts "#{key}: #{val}"
      end
    end
  end

  def get_views   # read from filesystem
#   Dir.chdir(::Home) do
      verify(@root => "#@root is nil",
             Dir.exist?(@root) => "#@root doesn't exist",
             Dir.exist?("#@root/views") => "#@root/views doesn't exist")
      dirs = subdirs("#@root/views/").sort
      dirs.map {|name| RuneBlog::View.new(name) }
#   end
  end

  def new_dotfile(root: ".blogs", current_view: "test_view", editor: "vi")
#   raise BlogAlreadyExists if Dir.exist?(".blogs")
#   Dir.mkdir(".blogs")
    root = Dir.pwd + "/" + root
    x = OpenStruct.new
    x.root, x.current_view, x.editor = root, current_view, editor
    write_config(x, ".blogs/" + RuneBlog::ConfigFile)
  end

  def new_sequence
    dump(0, "sequence")
    version_info = "#{RuneBlog::VERSION}\nBlog created: #{Time.now.to_s}"
    dump(version_info, "VERSION")
  end

  def subdirs(dir)
    verify(Dir.exist?(dir) => "Directory #{dir} not found")
    dirs = Dir.entries(dir) - %w[. ..]
    dirs.reject! {|x| ! File.directory?("#@root/views/#{x}") }
    dirs
  end

  def find_draft_slugs
    verify(@root => "#@root is nil",
           Dir.exist?(@root) => "#@root doesn't exist",
           Dir.exist?("#@root/drafts") => "#@root/drafts doesn't exist")
    files = Dir["#@root/drafts/**"].grep /\d{4}.*.lt3$/
    flagfile = "#@root/drafts/last_rebuild"
    last = File.exist?(flagfile) ? File.mtime(flagfile) : (Time.now - 86_400)
    files.reject! {|f| File.mtime(f) > last }
    files.map! {|f| File.basename(f) }
    files = files.sort.reverse
    debug "fss: #{files.inspect}"
    files
  end

  def create_dirs(*dirs)
    dirs.each do |dir|
      dir = dir.to_s  # symbols allowed
      next if Dir.exist?(dir)
      cmd = "mkdir -p #{dir} >/dev/null"
      result = system(cmd) 
      raise CantCreateDir(dir) unless result
    end
  end

  def interpolate(str, binding)
    wrap = "<<-EOS\n#{str}\nEOS"
    eval wrap, binding
  end

  def error(err)  # Hmm, this is duplicated
    str = "\n  Error: #{err}"
    puts str
    puts err.backtrace.join("\n")
  end

  def dump(obj, name)
    File.write(name, obj)
  end

end

def dump(obj, name)      # FIXME scope
  File.write(name, obj)
end

