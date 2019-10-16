
LEXT = ".lt3"

  def stale?(src, dst, force = false)
    log!(enter: __method__, args: [src, dst], level: 3)
    raise "Source #{src} not found in #{Dir.pwd}" unless File.exist?(src)
    return true if force
    return true unless File.exist?(dst)
    return true if File.mtime(src) > File.mtime(dst)
    return false
  end

  def xlate(cwd: Dir.pwd, src:, 
            dst: (strip = true; src.sub(/.lt3$/,"")), 
            copy: nil, debug: false, force: false)
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
      if stale?(src, dst, force)
        # do nothing
      else
        STDERR.puts "#{indent} -- ^ Already up to date!" if debug
        return
      end
      rc = system("livetext #{src} >#{dst}")
      STDERR.puts "...completed (shell returned #{rc})" if debug
      system!("cp #{dst} #{copy}") if copy
    end
  end

  def xlate!(cwd: Dir.pwd, src:, copy: nil, debug: false, force: false)
    output = "/tmp/xlate-#{File.basename(src).sub(/.lt3$/, "")}"
    xlate cwd: cwd, src: src, dst: output, debug: debug, force: force
    File.read(output + ".html")  # return all content as string
  end
