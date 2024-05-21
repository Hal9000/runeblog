if !defined?(RuneBlog::Path)

require 'pathname'

class RuneBlog
  VERSION = "0.3.36"

  path = Gem.find_files("runeblog").grep(/runeblog-/).first
  path ||= Pathname(__FILE__).realpath.dirname.to_s

  Path  = File.dirname(path)   # inside gem or dev repo
end

# skeleton

class RuneBlog
  module Helpers
  end

  class Default
  end

  class View
  end

  class Publishing
  end

  class Post
  end
end

# Refactor, move elsewhere?

def prefix(num)
  log!(enter: __method__, args: [num], level: 3)
  "#{'%04d' % num.to_i}"
end

end
