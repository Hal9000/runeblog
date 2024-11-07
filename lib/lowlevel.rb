  private def whence(back = 0)
    file, line, inmeth = caller[back].split(":")
    meth = inmeth[4..-2]
    [file, line, meth]
  end

  private def display(file, line, meth, msg)
    puts "\n--- #{meth}  #{line} in #{file}"
    puts "::: " + msg if msg
  end

  def checkpoint(msg = nil)
    return unless $debug
    file, line, meth = whence(1)
    display(file, line, meth, msg)
  end

  def checkpoint?(msg = nil)        # with sleep 3
    return unless $debug
    file, line, meth = whence(1)
    display(file, line, meth, msg)
  end

  def checkpoint!(msg = nil)        # with pause
    return unless $debug
    file, line, meth = whence(1)
    display(file, line, meth, msg)
    print "::: Pause..."
    gets
  end

  def warning(err)
    file, line, meth = whence(2)  # 2 = skip rescue
    puts "Error in #{meth} in #{file} (non-fatal?)"
    puts "      err = #{err.inspect}"
    puts "      #{err.backtrace[0]}" if err.respond_to?(:backtrace)
    puts
  end

  def fatal(err)
    file, line, meth = whence(2)  # 2 = skip rescue
    puts "Error in #{meth} in #{file}"
    puts "WTF??"
    puts  "     err = #{err.inspect}"
    if err.respond_to?(:backtrace)
      context = err.backtrace.map {|x| "     " + x + "\n" }
      puts context
    end
    abort "Terminated."
  end

  def _tmp_error(err)
    STDERR.puts err
    STDERR.puts err.backtrace.join("\n") if err.respond_to?(:backtrace)
    log!(str: "#{err} - see also stderr.out")
    log!(str: err.backtrace.join("\n")) if err.respond_to?(:backtrace)
  end

  def dump(obj, name)
    File.write(name, obj)
  end

  def timelog(line, file)
    File.open(file, "a") {|f| f.puts "#{Time.now} #{line}" }
  end

  def system!(os_cmd, show: false)
    log!(enter: __method__, args: [os_cmd], level: 2)
    STDERR.puts os_cmd if show
    rc = system(os_cmd)
    STDERR.puts "  rc = #{rc.inspect}" if show
    return rc if rc
    STDERR.puts "FAILED: #{os_cmd.inspect}"
    STDERR.puts "\ncaller = \n#{caller.join("\n  ")}\n"
    if defined?(RubyText)
      sleep 6
      RubyText.stop
      exit
    end
    return rc
  end

  def _get_data?(file)   # File need not exist
    log!(enter: __method__, args: [file], level: 2)
    File.exist?(file) ? _get_data(file) : []
  end

  def _get_data(file)
    log!(enter: __method__, args: [file], level: 2)
    lines = File.readlines(file)
    lines = lines.map do |line|
      line = line.chomp.strip
      line.sub(/ *# .*$/, "")    # allow leading/trailing comments
    end
    lines.reject! {|x| x.empty? }
    lines
  end

  def read_pairs(file)       # returns a hash
    log!(enter: __method__, args: [file], level: 2)
    lines = _get_data(file)
    hash = {}
    lines.each do |line|
      key, val = line.split(" ", 2)
      val ||= ""
      hash[key] = val
    end
    hash
  end

  def read_pairs!(file)       # returns an openstruct
    log!(enter: __method__, args: [file], level: 2)
    lines = _get_data(file)
    obj = OpenStruct.new
    lines.each do |line|
      key, val = line.split(" ", 2)
      val ||= ""
      obj.send("#{key}=", val)
    end
    obj
  end

  def copy(src, dst)
    log!(enter: __method__, args: [src, dst], level: 2)
    cmd = "cp #{src} #{dst} 2>/dev/null"
    system!(cmd)
  end

  def copy!(src, dst)
    log!(enter: __method__, args: [src, dst], level: 2)
    cmd = "cp -r #{src} #{dst} 2>/dev/null"
    system!(cmd)
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

  def error(err)
    log!(str: err, enter: __method__, args: [err], level: 2)
    str = "\n  Error... #{err}"
    puts str
    puts err.backtrace.join("\n")
  end

  def find_item(list, &block)
    log!(enter: __method__, args: [list], level: 2)
    list2 = list.select(&block)
    exactly_one(list2, list.join("/"))
  end

  def find_item!(list, &block)
    log!(enter: __method__, args: [list], level: 2)
    list2 = list.select(&block)
    list2 = list.select(&block)
    item = exactly_one(list2, list.join("/"))
    n = list.index(&block)
    [n, item]
  end

  def exactly_one(list, tag = nil, &block)
    log!(enter: __method__, args: [list], level: 2)
    list2 = list.select(&block)
    raise "List: Zero instances #{"- #{tag}" if tag}" if list.empty?
    raise "List: More than one instance #{"- #{tag}" if tag}" if list.size > 1
    list.first
  end

  def addvar(vars, hash)
    hash.each_pair do |k, v| 
      vars[k.to_s] = v
      vars[k.to_sym] = v
    end
    vars
  end
