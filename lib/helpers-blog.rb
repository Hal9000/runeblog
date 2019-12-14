require 'runeblog_version'
require 'fileutils'

require 'processing'

module RuneBlog::Helpers

  def copy(src, dst)
    log!(enter: __method__, args: [src, dst], level: 2)
    cmd = "cp #{src} #{dst} 2>/dev/null"
    rc = system!(cmd)
    puts "    Failed: #{cmd} - from #{caller[0]}" unless rc
  end

  def copy!(src, dst)
    log!(enter: __method__, args: [src, dst], level: 2)
    cmd = "cp -r #{src} #{dst} 2>/dev/null"
    rc = system!(cmd)
    puts "    Failed: #{cmd} - from #{caller[0]}" unless rc
  end

  def get_repo_config
    log!(enter: __method__, level: 3)
    @editor = File.read(".blogs/data/EDITOR").chomp
    @current_view = File.read(".blogs/data/VIEW").chomp
    @root = File.read(".blogs/data/ROOT").chomp
  rescue => err
    puts "Can't read config: #{err}"
    puts err.backtrace.join("\n")
    puts "dir = #{Dir.pwd}"
  end

  def copy_data(tag, dest)
    data = RuneBlog::Path + "/../data"  # files kept inside gem
    case tag
      when :config; files = %w[ROOT VIEW EDITOR universal.lt3 global.lt3]
    end
    files.each {|file| copy(data + "/" + file, dest) }
  end

  def read_vars(file)
    log!(enter: __method__, args: [file], level: 3)
    lines = File.readlines(file).map(&:chomp)
    hash = {}
    skip = ["\n", "#", "."]
    lines.each do |line|
      line = line.strip
      next if skip.include?(line[0])
      key, val = line.split(" ", 2)
      hash[key] = val
    end
    hash
  rescue => err
    puts "Can't read vars file '#{file}': #{err}"
    puts err.backtrace.join("\n")
    puts "dir = #{Dir.pwd}"
    exit
  end

  def read_config(file, *syms)
    log!(enter: __method__, args: [file, *syms], level: 3)
    lines = File.readlines(file).map(&:chomp)
    obj = ::OpenStruct.new
    skip = ["\n", "#", "."]
    lines.each do |line|
      next if skip.include?(line[0])
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
    log!(enter: __method__, args: [file, hash], level: 3)
    return hash.values unless File.exist?(file)
    vals = read_config(file, *hash.keys)
    vals
  end

  def write_config(obj, file)
    log!(enter: __method__, args: [obj, file], level: 2)
    hash = obj.to_h
    File.open(file, "w") do |out|
      hash.each_pair {|key, val| out.puts "#{key}: #{val}" }
    end
  end

  def get_views   # read from filesystem
    log!(enter: __method__, level: 3)
    dirs = subdirs("#@root/views/").sort
    dirs.map {|name| RuneBlog::View.new(name) }
  end

  def write_repo_config(root: "#{Dir.pwd}/.blogs", view: "#{root}/data/VIEW", editor: "#{root}/data/EDITOR")
    File.write(root + "/data/ROOT",   root + "\n")
    File.write(root + "/data/VIEW",   view.to_s + "\n")
    File.write(root + "/data/EDITOR", editor + "\n")
  end

  def new_dotfile(root: ".blogs", current_view: "test_view", editor: "vi")
    log!(enter: __method__, args: [root, current_view, editor], level: 3)
    root = Dir.pwd + "/" + root
    x = OpenStruct.new
    x.root, x.current_view, x.editor = root, current_view, editor
    write_config(x, root + "/" + RuneBlog::ConfigFile)
    write_repo_config
  end

  def new_sequence
    log!(enter: __method__, level: 3)
    dump(0, "sequence")
    version_info = "#{RuneBlog::VERSION}\nBlog created: #{Time.now.to_s}"
    dump(version_info, "VERSION")
  end

  def subdirs(dir)
    log!(enter: __method__, args: [dir], level: 3)
    dirs = Dir.entries(dir) - %w[. ..]
    dirs.reject! {|x| ! File.directory?("#@root/views/#{x}") }
    dirs
  end

  def find_draft_slugs
    log!(enter: __method__, level: 3)
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
    log!(enter: __method__, args: [*dirs], level: 3)
    dirs.each do |dir|
      dir = dir.to_s  # symbols allowed
      next if Dir.exist?(dir)
      cmd = "mkdir -p #{dir} >/dev/null"
      result = system!(cmd) 
      raise CantCreateDir(dir) unless result
    end
  end

  def interpolate(str, bind)
    log!(enter: __method__, args: [str, bind], level: 3)
    wrap = "<<-EOS\n#{str}\nEOS"
    eval wrap, bind
  end

  def error(err)  # Hmm, this is duplicated
    log!(str: "duplicated method", enter: __method__, args: [err], level: 2)
    str = "\n  Error: #{err}"
    puts str
    puts err.backtrace.join("\n")
  end

  def dump(obj, name)
    log!(enter: __method__, args: [obj, name], level: 3)
    File.write(name, obj)
  end
end

def dump(obj, name)      # FIXME scope
  log!(str: "scope problem", enter: __method__, args: [obj, name], level: 3)
  File.write(name, obj)
end

