if ! defined?(LIVE)

require 'livetext'

LIVE = Livetext.new
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

def preprocess(cwd: Dir.pwd, src:, 
          dst: (strip = true; File.basename(src).sub(/.lt3$/,"")), 
          deps: [], copy: nil, debug: false, force: false, 
          mix: [], call: [], vars: {})
  src += LEXT unless src.end_with?(LEXT)
  dst += ".html" unless (dst.end_with?(".html") || strip)
  sp = " "*12
  Dir.chdir(cwd) do
    if debug
      STDERR.puts "#{sp} -- preprocess "
      STDERR.puts "#{sp}      src:  #{src}"
      STDERR.puts "#{sp}      dst:  #{dst}"
      STDERR.puts "#{sp}      in:   #{Dir.pwd}"
      STDERR.puts "#{sp}      from: #{caller[0]}"
      STDERR.puts "#{sp}      copy: #{copy}" if copy
    end
    stale = stale?(src, dst, deps, force)
    if stale
      live = Livetext.customize(mix: "liveblog", call: call, vars: vars)
      out = live.xform_file(src)
      File.write(dst, out)
      system!("cp #{dst} #{copy}") if copy
    end
    puts "#{sp} -- ^ Already up to date!" if debug && ! stale
  end
end

def get_live_vars(src)
  live = Livetext.customize(call: [".nopara"])
  live.xform_file(src)
  live
end

end
