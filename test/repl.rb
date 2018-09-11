$LOAD_PATH << "."

require "minitest/autorun"

require 'lib/repl'

class TestREPL < Minitest::Test
  include RuneBlog::REPL

  def setup
    Dir.chdir("/Users/Hal/Dropbox/files/blog") # temp code!!
    @blog ||= open_blog
  end

  def test_001_cmd_help
    out = cmd_help([])
    assert out.is_a?(String), "Expected a string returned"
    lines = out.split("\n").length 
    assert lines > 25, "Expecting lengthy help message"
  end

  def test_002_cmd_version
    out = cmd_version([])
    assert out.is_a?(String), "Expected a string returned"
    lines = out.split("\n")[1]
    assert lines =~ /\d+\.\d+\.\d+/m,
           "Couldn't find version number"
  end

  def test_003_list_views
    out = cmd_list_views([])
    assert out.is_a?(String), "Expected a string returned"
    lines = out.split("\n").length 
    assert lines >= 2, "Expecting at least 2 lines"
  end

  def test_004_change_view
    out = cmd_change_view([])  # no param
    assert out.is_a?(String), "Expected a string returned"
    assert out =~ /computing/m, "Expecting 'computing' as default; got: #{out.inspect}"
  end

  def test_005_lsd
    out = cmd_list_drafts([])
    assert out.is_a?(String), "Expected a string returned"
    lines = out.split("\n").length 
    assert lines >= 15, "Expecting more lines; got: #{out.inspect}"
  end

  def test_006_lsp
    out = cmd_list_posts([])
    assert out.is_a?(String), "Expected a string returned; got: #{out.inspect}"
    lines = out.split("\n").length 
    assert lines >= 20, "Expecting more lines; got: #{out.inspect}"
  end

  def test_007_parser
    parse_tests = {
      "kill 81 82 83"   => [:cmd_kill, "81 82 83"],
      " kill 81 82 83"  => [:cmd_kill, "81 82 83"],
      "kill 81 82 83 "  => [:cmd_kill, "81 82 83"],
      " kill 81 82 83 " => [:cmd_kill, "81 82 83"]
    }

    parse_tests.each_pair do |cmd, expected|
      result = RuneBlog::REPL.choose_method(cmd)
      assert result == expected, "Expected #{expected.inspect} but got #{result.inspect}"
    end
  end
end

