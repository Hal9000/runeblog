if !defined?(RuneBlog::Path)

class RuneBlog
  VERSION = "0.3.27"

  path = Gem.find_files("runeblog").grep(/runeblog-/).first
  Path  = File.dirname(path)
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
