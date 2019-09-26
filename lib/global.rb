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
  log!(enter: __method__, args: [sym, str])
  return if Object.constants.include?(sym)
  Object.const_set(sym, StandardError.dup)
  define_method(sym) do |*args|
    msg = str
    args.each.with_index {|arg, i| msg.sub!("$#{i+1}", arg) }
    Object.class_eval(sym.to_s).new(msg)
  end
end

def prefix(num)
  log!(enter: __method__, args: [num])
  "#{'%04d' % num.to_i}"
end

def check_meta(meta, where = "")
  log!(enter: __method__, args: [meta, where])
  str =  "--- #{where}\n"
  str << "\ncheck_meta: \n" + caller.join("\n") + "\n  meta = #{meta.inspect}\n"
  str << "  title missing!\n" unless meta.title
  str << "  title missing! (empty)" if meta.title && meta.title.empty?
  str << "  num missing!\n" unless meta.num
  if str =~ /missing!/
    debug str
    raise str 
  end
end

def verify(hash)
  log!(enter: __method__, args: [hash])
  hash.each_pair do |expr, msg|
    puts "<< #{msg}" unless expr
  end
end

def assure(hash)  # really the same as verify for now...
  log!(enter: __method__, args: [hash])
  hash.each_pair do |expr, msg|
    puts "<< #{msg}" unless expr
  end
end
