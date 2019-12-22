if !defined?(RuneBlog::Path)

# if ! (Object.constants.include?(:RuneBlog) && RuneBlog.constants.include?(:Path))

class RuneBlog
  VERSION = "0.2.95"

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

# Refactor, move stuff elsewhere?

def make_exception(sym, str)
  log!(enter: __method__, args: [sym, str], level: 3)
  return if Object.constants.include?(sym)
  Object.const_set(sym, StandardError.dup)
  define_method(sym) do |*args|
    msg = str
    args.each.with_index {|arg, i| msg.sub!("$#{i+1}", arg) }
    Object.class_eval(sym.to_s).new(msg)
  end
end

def prefix(num)
  log!(enter: __method__, args: [num], level: 3)
  "#{'%04d' % num.to_i}"
end


end
