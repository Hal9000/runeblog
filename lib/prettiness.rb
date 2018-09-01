
# Reopening...

module RuneBlog::REPL
  def clear
    puts "\e[H\e[2J"  # clear screen
  end

  def red(text)
    "\e[31m#{text}\e[0m"
  end

  def blue(text)
    "\e[34m#{text}\e[0m"
  end

  def bold(str)
    "\e[1m#{str}\e[22m"
  end

  def interpolate(str)
    wrap = "<<-EOS\n#{str}\nEOS"
    eval wrap
  end

  def colored_slug(slug)
    red(slug[0..3])+blue(slug[4..-1])
  end
end
