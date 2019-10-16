unless self.respond_to?("log!")
  $logging = true
  $log = File.new("/tmp/runeblog.log","w")

  def outlog(str = "", stderr: false)
    $log.puts str
    STDERR.puts str if stderr
  end

  def log!(str: "", enter: nil, args: [], pwd: false, dir: false, level: 0, stderr: false)
    return unless $logging
    @err_level ||= ENV['RUNEBLOG_ERROR_LEVEL']
    @err_level ||= 0
    return if level < @err_level 

    time = Time.now.strftime("%H:%M:%S")

    meth = ""
    meth = "#{enter}" if enter

    para = "(#{args.inspect[1..-2]})"

    source = caller[0].sub(/.*\//, " in ").sub(/:/, " line ").sub(/:.*/, "")
    source = "in #{source} (probably liveblog.rb)" if source.include? "(eval)"

    str = "  ... #{str}" unless str.empty?
    indent = " "*12

    outlog "#{time} #{meth}#{para}"
    outlog "#{indent} #{str} " unless str.empty?
    outlog "#{indent} #{source}"
    outlog "#{indent} pwd = #{Dir.pwd} " if pwd
    if dir
      files = (Dir.entries('.') - %w[. ..]).join(" ")
      outlog "#{indent} dir/* = #{files}"
    end
#   outlog "#{indent} livetext params = #{livedata.inpect} " unless livedata.nil?
    outlog 
    $log.close
    $log = File.new("/tmp/runeblog.log","a")
  end

end

