
  def _tmp_error(err)
    out = "/tmp/blog#{rand(100)}.txt"
    File.open(out, "w") do |f|
      f.puts err.to_s + "\n--------"
      f.puts err.backtrace.join("\n")
    end
    puts "Error: See #{out}"
  end

  def dump(obj, name)
    File.write(name, obj)
  end

  def timelog(line, file)
    File.open(file, "a") {|f| f.puts "#{Time.now} #{line}" }
  end

  def system!(str, show: false)
    log!(enter: __method__, args: [str], level: 2)
    STDERR.puts str if show
    rc = system(str)
    return rc if rc
    STDERR.puts "FAILED: #{str.inspect}"
    STDERR.puts "\ncaller = \n#{caller.join("\n  ")}\n"
    if defined?(RubyText)
      sleep 6
      RubyText.stop
      exit
    end
    return rc
  end

  def _get_data?(file)   # File need not exist
    File.exist?(file) ? _get_data(file) : []
  end

  def _get_data(file)
    lines = File.readlines(file)
    lines = lines.map do |line|
      line = line.chomp.strip
      line.sub(/ *# .*$/, "")    # allow leading/trailing comments
    end
    lines.reject! {|x| x.empty? }
    lines
  end

  def read_pairs(file)       # returns a hash
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
    # log!(str: err, enter: __method__, args: [err], level: 2)
    str = "\n  Error: #{err}"
    puts str
    puts err.backtrace.join("\n")
  end

  def exactly_one(list)
    raise "List: Zero instances" if list.empty?
    raise "List: More than one instance" if list.size > 1
    list.first
  end

