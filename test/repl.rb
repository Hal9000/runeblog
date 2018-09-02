$LOAD_PATH << "."

require "minitest/autorun"

require 'lib/repl'

class Duh
  include RuneBlog::REPL
end

class TestREPL < Duh
end
