
LEXT = ".lt3"

def newer?(f1, f2)
  File.mtime(f1) > File.mtime(f2)
end

def stale?(src, dst, deps, force = false)
  meh = File.new("/tmp/dammit-#{src.gsub(/\//, "-")}", "w")
  log!(enter: __method__, args: [src, dst], level: 3)
  raise "Source #{src} not found in #{Dir.pwd}" unless File.exist?(src)
  return true if force
  return true unless File.exist?(dst)
  return true if newer?(src, dst)
  deps.each {|dep| return true if newer?(dep, dst) }
  return false
end

def xlate(cwd: Dir.pwd, src:, 
          dst: (strip = true; src.sub(/.lt3$/,"")), 
          deps: [], copy: nil, debug: false, force: false)
  src += LEXT unless src.end_with?(LEXT)
  dst += ".html" unless dst.end_with?(".html") || strip
  indent = " "*12
  Dir.chdir(cwd) do
    if debug
      STDERR.puts "#{indent} -- xlate #{src} >#{dst}"
      STDERR.puts "#{indent}      in:   #{Dir.pwd}"
      STDERR.puts "#{indent}      from: #{caller[0]}"
      STDERR.puts "#{indent}      copy: #{copy}" if copy
    end
    stale = stale?(src, dst, deps, force)
    if stale
      rc = system("livetext #{src} >#{dst}")
      STDERR.puts "...completed (shell returned #{rc})" if debug
      system!("cp #{dst} #{copy}") if copy
    else
      STDERR.puts "#{indent} -- ^ Already up to date!" if debug
      return
    end
  end
end

def xlate!(cwd: Dir.pwd, src:, copy: nil, debug: false, force: false)
  output = "/tmp/xlate-#{File.basename(src).sub(/.lt3$/, "")}"
  xlate cwd: cwd, src: src, dst: output, debug: debug, force: force
  File.read(output + ".html")  # return all content as string
end
