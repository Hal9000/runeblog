
if ! (Object.constants.include?(:RuneBlog) && RuneBlog.constants.include?(:Path))

class RuneBlog
  VERSION = "0.2.56"

  path = Gem.find_files("runeblog").grep(/runeblog-/).first
  Path  = File.dirname(path)
end

end
