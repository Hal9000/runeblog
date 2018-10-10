module RuneBlog::Helpers

  def read_config(file, *syms)
    lines = File.readlines(file).map(&:chomp)
    obj = OpenStruct.new
    lines.each do |line|
      key, val = line.split(" ", 2)
      key = key[0..-2] # remove colon
      obj.send(key+"=", val)
    end
    return obj if syms.empty?
    vals = []
    syms.each {|sym| vals << obj.send(sym) }
    return vals
  rescue => err
    puts "Something hit the fan: #{err}"
    puts err.backtrace
    exit
  end

  def huh_read_config(file, *syms)
    lines = File.readlines(file).map(&:chomp)
    obj = OpenStruct.new
    lines.each do |line|
      key, val = line.split(" ", 2)
      key = key[0..-2] # remove colon
      obj.send(key+"=", val)
    end
    @deployer = RuneBlog::Deployment.new(obj)
    obj
  rescue => err
    puts "Something hit the fan: #{err}"
    puts err.backtrace
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
    x = OpenStruct.new
    x.root, x.current_view, x.editor = root, current_view, editor
    write_config(x, RuneBlog::DotFile)
  end

  def new_sequence
    File.write("sequence", 0)
    File.write("VERSION", "#{RuneBlog::VERSION}\n" + 
                          "Blog created: " + Time.now.to_s)
  end

  def subdirs(dir)
    dirs = Dir.entries(dir) - %w[. ..]
    dirs.reject! {|x| ! File.directory?("#@root/views/#{x}") }
    dirs
  end

  def find_src_slugs
    files = Dir.entries("#@root/src/").grep /\d{4}.*.lt3$/
    files.map! {|f| File.basename(f) }
    files = files.sort.reverse
    files
  end

  def create_dir(dir)
    return if File.exist?(dir) && File.directory?(dir)
    cmd = "mkdir -p #{dir} >/dev/null 2>&1"
    result = system(cmd) 
    raise "Can't create #{dir}" unless result
  end

  def interpolate(str)
    wrap = "<<-EOS\n#{str}\nEOS"
    eval wrap
  end

  def error(err)  # Hmm, this is duplicated
    str = "\n  Error: #{err}"
    puts str
    puts err.backtrace
  end

end
