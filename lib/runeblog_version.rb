
if ! (Object.constants.include?(:RuneBlog) && RuneBlog.constants.include?(:Path))

class RuneBlog
  VERSION = "0.1.89"

  path = Gem.find_files("runeblog").grep(/runeblog-/).first
  Path  = File.dirname(path)
end

end
