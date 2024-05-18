require 'runeblog_version'
require 'fileutils'

require 'processing'

require 'pathmagic'
require 'lowlevel'

module RuneBlog::Helpers

  def quit_RubyText
    return unless defined? RubyText
    sleep 6
    RubyText.stop
    exit
  end

  def read_features(view = nil)
    hash = {}
    root = @blog.root rescue ".blogs"
    if view.nil?  # toplevel
      dir = root/"data"
    else
      dir = root/:views/view/:settings
    end
    file = dir/"features.txt"
    pairs = read_pairs(file)
    enabled = {}
    pairs.each {|k,v| enabled[k] = (v == "1") }
    @features = enabled
  end

  def write_features(hash, view = nil)
    root = @blog.root rescue ".blogs"
    if view.nil?  # toplevel
      dir = root/"data"
    else
      dir = root/:views/view/:settings
    end
    file = dir/"features.txt"
    lines = File.readlines(file)
    names = hash.keys
    names.each do |name|
      n, item = find_item!(lines) {|x| x =~ /^#{name} / }
      k = name.length + 1  # 2nd blank after name
      loop { break if item[k] != " "; k += 1 }
      item[k] = hash[name]
      lines[n] = item
    end
    File.write(file, lines.join)
  rescue => err
    puts "Error: #{err}"
    puts err.backtrace.join("\n")
    puts
  end

  def get_repo_config(root = ".blogs")
    log!(enter: __method__, level: 3)
    @editor = File.read("#{root}/data/EDITOR").chomp
    @current_view = File.read("#{root}/data/VIEW").chomp
    @root = File.read("#{root}/data/ROOT").chomp  
    # Huh? Why not just @root = root?  Hal.wtf?
  rescue => err
    puts "Can't read config: #{err}"
    puts err.backtrace.join("\n")
    puts "dir = #{Dir.pwd}"
  end

  def get_all_widgets(dest)
    wdir  = RuneBlog::Path + "/widgets"    # files kept inside gem (or dev repo)
    copy!(wdir/"*", dest)
  end

  def get_widget(dest, widget: :all)   # recursive
    wdir  = ".blogs/widgets"
    wdir  = RuneBlog::Path + "/widgets"    # files kept inside gem (or dev repo)
    if widget == :all
      copy!(wdir/"*", dest)
    else
      copy!(wdir/widget, dest)
    end
  end 

  def copy_data(dest)
    data  = RuneBlog::Path + "/../data"    # files kept inside gem (or dev repo)
    files = %w[ROOT VIEW EDITOR universal.lt3 global.lt3 features.txt]
    files.each {|file| copy(data + "/" + file, dest) unless File.exist?(dest/file) }
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
      next if key.nil?
      hash[key] = hash[key.to_sym] = val
    end
    hash
  rescue => err
    puts "Can't read vars file '#{file}': #{err}"
    puts err.backtrace.join("\n")
    puts "dir = #{Dir.pwd}"
    stop_RubyText rescue nil
  end

  def write_repo_config(root: "#{Dir.pwd}/.blogs", view: nil, editor: "/usr/local/bin/vim")
    view ||= File.read("#{root}/data/VIEW").chomp rescue "[no view]"
    File.write(root + "/data/ROOT",   root + "\n")
    File.write(root + "/data/VIEW",   view.to_s + "\n")
    File.write(root + "/data/EDITOR", editor + "\n")
  end

  def new_sequence
    log!(enter: __method__, level: 3)
    dump(0, "data/sequence")
    version_info = "#{RuneBlog::VERSION}\nBlog created: #{Time.now.to_s}"
    dump(version_info, "data/VERSION")
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

end


