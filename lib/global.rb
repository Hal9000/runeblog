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

def make_exception(sym, str)
  return if Object.constants.include?(sym)
  Object.const_set(sym, StandardError.dup)
  define_method(sym) do |*args|
    msg = str
    args.each.with_index {|arg, i| msg.sub!("$#{i+1}", arg) }
    Object.class_eval(sym.to_s).new(msg)
  end
end

def prefix(num)
  "#{'%04d' % num.to_i}"
end

def check_meta(meta, where = "")
  str =  "--- #{where}\n"
  str << "\ncheck_meta: \n" + caller.join("\n") + "\n  meta = #{meta.inspect}\n"
  str << "  title missing!\n" unless meta.title
  str << "  title missing! (empty)" if meta.title && meta.title.empty?
  str << "  num missing!\n" unless meta.num
  if str =~ /missing!/
    debug str
exit
    raise str 
  end
end

