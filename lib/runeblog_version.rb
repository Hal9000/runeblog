
if ! (Object.constants.include?(:RuneBlog) && RuneBlog.constants.include?(:Path))

class RuneBlog
  VERSION = "0.1.78"

  Path  = File.expand_path(File.join(File.dirname(__FILE__)))
end

end
