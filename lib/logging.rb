unless self.respond_to?("log!")
  $logging = true
  $log = File.new("/tmp/runeblog.log","w")

  def log!(str: "", enter: nil, args: [], pwd: false, dir: false)
    return unless $logging
    time = Time.now.strftime("%H:%M:%S")

    meth = ""
    meth = "#{enter}" if enter

    para = "(#{args.inspect[1..-2]})"

    source = caller[0].sub(/.*\//, " in ").sub(/:/, " line ").sub(/:.*/, "")
    source = "in #{source} (probably liveblog.rb)" if source.include? "(eval)"

    str = "  ... #{str}" unless str.empty?
    indent = " "*12

    $log.puts "#{time} #{meth}#{para}"
    $log.puts "#{indent} #{str} " unless str.empty?
    $log.puts "#{indent} #{source}"
    $log.puts "#{indent} pwd = #{Dir.pwd} " if pwd
    if dir
      files = (Dir.entries('.') - %w[. ..]).join(" ")
      $log.puts "#{indent} dir/* = #{files}"
    end
#   $log.puts "#{indent} livetext params = #{livedata.inpect} " unless livedata.nil?
    $log.puts
    $log.close
    $log = File.new("/tmp/runeblog.log","a")
  end

#   def log(str: "", enter: nil, args: [], pwd: false, dir: false)
#     return unless $logging
#     time = Time.now.strftime("%H:%M:%S")
#     meth = ""
#     meth = "#{enter}" if enter
#     para = " args: #{args.inspect[1..-2]}"
#     source = caller[0].sub(/.*\//, " in ").sub(/:/, " line ").sub(/:.*/, "")
#     source = " in #{source} (probably liveblog.rb)" if source.include? "(eval)"
#     str = "  ... #{str}" unless str.empty?
#     indent = " "*12
#     STDERR.puts "#{time} #{str} #{meth}"
#     STDERR.puts "#{indent} #{source}"
#     STDERR.puts "#{indent} pwd = #{Dir.pwd} " if pwd
#     if dir
#       files = (Dir.entries('.') - %w[. ..]).join(" ")
#       STDERR.puts "#{indent} dir/* = #{files}"
#     end
#     STDERR.puts "#{indent} #{para} " unless args.empty?
#   # STDERR.puts "#{indent} livetext params = #{livedata.inpect} " unless livedata.nil?
#     STDERR.puts
#     # $log.close
#     # $log = File.new("/tmp/runeblog.log","a")
#   end
end

