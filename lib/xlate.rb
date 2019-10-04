
LEXT = ".lt3"

  def stale?(src, dst, force = false)
    log!(enter: __method__, args: [src, dst])
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
    STDERR.puts "-- xlate: pwd = #{cwd}"
    Dir.chdir(cwd) do
      return unless stale?(src, dst, force)
      if debug
        STDERR.puts "-- xlate #{src} >#{dst}"
        STDERR.puts "     in:   #{Dir.pwd}"
        STDERR.puts "     from: #{caller[0]}"
        STDERR.puts "     copy: #{copy}" if copy
      end
      rc = system("livetext #{src} >#{dst}")
      STDERR.puts "...completed (shell returned #{rc})" if debug
    end
  end

