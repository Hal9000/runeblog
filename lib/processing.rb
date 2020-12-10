if ! defined?(LIVE)

require 'livetext'

LIVE = "defined"
LEXT = ".lt3"

def newer?(f1, f2)
  File.mtime(f1) > File.mtime(f2)
end

def stale?(src, dst, deps, force = false)
  meh = File.new("/tmp/dammit-#{src.gsub(/\//, "-")}", "w")
  log!(enter: __method__, args: [src, dst], level: 3)
  raise FileNotFound("#{Dir.pwd}/#{src}") unless File.exist?(src)
  return true if force
  return true unless File.exist?(dst)
  return true if newer?(src, dst)
  deps.each {|dep| return true if newer?(dep, dst) }
  return false
end

def preprocess(cwd: Dir.pwd, src:, 
               dst: nil, strip: false,
               deps: [], copy: nil, debug: false, force: false, 
               mix: [], call: [], 
               vars: {})
  src += LEXT unless src.end_with?(LEXT)
  if strip
    dst = File.basename(src).sub(/.lt3$/,"")
  else
    dst += ".html" unless dst.end_with?(".html")
  end
  sp = " "*12

  Dir.chdir(cwd) do
    if debug
      STDERR.puts "#{sp} -- preprocess "
      STDERR.puts "#{sp}      src:  #{src}"
      STDERR.puts "#{sp}      dst:  #{dst}"
      STDERR.puts "#{sp}      in:   #{Dir.pwd}"
      STDERR.puts "#{sp}      from: #{caller[0]}"
      STDERR.puts "#{sp}      copy: #{copy}" if copy
      STDERR.puts "#{sp}      vars: #{vars.inspect}" unless vars == {}
      STDERR.flush
    end
    stale = stale?(src, dst, deps, force)
    STDERR.puts <<~EOF if debug
      STALE = #{stale}
      cwd = #{cwd.inspect}
      src = #{src.inspect}
      dst = #{dst.inspect}
      strip = #{strip.inspect}
      deps = #{deps.inspect}
      copy = #{copy.inspect}
      debug = #{debug.inspect}
      force = #{force.inspect}
      mix = #{mix.inspect}
      call = #{call.inspect}
      vars = #{vars.inspect}
    EOF
    if stale
      live = Livetext.customize(mix: "liveblog", call: call, vars: vars)
      log!(str: "Calling xform_file... src = #{src} pwd = #{Dir.pwd}")
      out = live.xform_file(src)
      File.write(dst, out)
      system!("cp #{dst} #{copy}") if copy
    end
    puts "#{sp} -- ^ Already up to date!" if debug && ! stale
  end
rescue => err
  msg = err.to_s
  msg << err.backtrace.join("\n") if err.respond_to?(:backtrace)
  STDERR.puts msg
  STDERR.flush
  log!(str: msg) 
end

def get_live_vars(src)
  live = Livetext.customize(call: [".nopara"])
# puts "glv: src = #{src.inspect}"
# STDERR.puts "glv: src = #{src.inspect}"
  live.xform_file(src)
  live
end

end
