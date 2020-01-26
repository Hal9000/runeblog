if !defined?(RuneBlog::Path)

# if ! (Object.constants.include?(:RuneBlog) && RuneBlog.constants.include?(:Path))

class RuneBlog
  VERSION = "0.3.15"

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

def make_exception(sym, str, target_class = Object)
  return if target_class.constants.include?(sym)

  target_class.const_set(sym, StandardError.dup)
  define_method(sym) do |*args|
    msg = str.dup
    args.each.with_index {|arg, i| msg.sub!("$#{i+1}", arg) }
    target_class.class_eval(sym.to_s).new(msg)
  end
end

def prefix(num)
  log!(enter: __method__, args: [num], level: 3)
  "#{'%04d' % num.to_i}"
end

end
