module RuneBlog::Helpers

  def read_config(file, *syms)
    lines = File.readlines(file).map(&:chomp)
    obj = OpenStruct.new
    lines.each do |line|
      next if line == "\n" || line[0] == "#"
      key, val = line.split(" ", 2)
      key = key[0..-2] # remove colon
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
    puts "Something hit the fan: #{err}"  # CHANGE_FOR_CURSES?
    puts err.backtrace  # CHANGE_FOR_CURSES?
    exit
  end

  def write_config(obj, file)
    hash = obj.to_h
    File.open(file, "w") do |f| 
      hash.each_pair do |key, val|
        f.puts "#{key}: #{val}"
      end
    end
  end

  def get_views   # read from filesystem
    dirs = subdirs("#@root/views/").sort
    dirs.map {|name| RuneBlog::View.new(name) }
  end

  def new_dotfile(root: "data", current_view: "no_default", editor: "vi")
    raise BlogAlreadyExists if Dir.exist?(".blog")
    Dir.mkdir(".blog")
    x = OpenStruct.new
    x.root, x.current_view, x.editor = root, current_view, editor
    write_config(x, RuneBlog::DotDir + "/config")
  end

  def new_sequence
    dump(0, "sequence")
    version_info = "#{RuneBlog::VERSION}\nBlog created: #{Time.now.to_s}"
    dump(version_info, "VERSION")
  end

  def subdirs(dir)
    dirs = Dir.entries(dir) - %w[. ..]
    dirs.reject! {|x| ! File.directory?("#@root/views/#{x}") }
    dirs
  rescue
    STDERR.puts "Can't find dir '#{dir}'"  # CHANGE_FOR_CURSES?
    exit
  end

  def find_src_slugs
    files = Dir.entries("#@root/src/").grep /\d{4}.*.lt3$/
    files.map! {|f| File.basename(f) }
    files = files.sort.reverse
    files
  end

  def create_dir(dir)
    return if Dir.exist?(dir)  #  && File.directory?(dir)
    cmd = "mkdir -p #{dir} >/dev/null 2>&1"
    result = system(cmd) 
    raise CantCreateDir(dir) unless result
  end

  def interpolate(str)
    wrap = "<<-EOS\n#{str}\nEOS"
    eval wrap
  end

  def error(err)  # Hmm, this is duplicated
    str = "\n  Error: #{err}"
    puts str  # CHANGE_FOR_CURSES?
    puts err.backtrace  # CHANGE_FOR_CURSES?
  end

  def dump(obj, name)
    File.write(name, obj)
  end

end
