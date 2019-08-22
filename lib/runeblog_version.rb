
if ! (Object.constants.include?(:RuneBlog) && RuneBlog.constants.include?(:Path))

class RuneBlog
  VERSION = "0.1.80"

  Path  = File.expand_path(File.join(File.dirname(__FILE__)))
end

end
