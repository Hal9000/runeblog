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
    out = cmd_help(nil)
    assert out.is_a?(String), "Expected a string returned"
    lines = out.split("\n").length 
    assert lines > 25, "Expecting lengthy help message"
  end

  def test_002_cmd_version
    out = cmd_version(nil)
    assert out.is_a?(String), "Expected a string returned"
    lines = out.split("\n")[1]
    assert lines =~ /\d+\.\d+\.\d+/m,
           "Couldn't find version number"
  end

  def test_003_list_views
    out = cmd_list_views(nil)
    assert out.is_a?(String), "Expected a string returned"
    lines = out.split("\n").length 
    assert lines >= 2, "Expecting at least 2 lines"
  end

  def test_004_change_view
    out = cmd_change_view(nil)  # no param
    assert out.is_a?(String), "Expected a string; got: #{out.inspect}"
    assert out =~ /computing/m, "Expecting 'computing' as default; got: #{out.inspect}"
  end

  def test_005_lsd
    out = cmd_list_drafts(nil)
    assert out.is_a?(String), "Expected a string returned"
    lines = out.split("\n").length 
    assert lines >= 15, "Expecting more lines; got: #{out.inspect}"
  end

  def test_006_lsp
    out = cmd_list_posts(nil)
    assert out.is_a?(String), "Expected a string returned; got: #{out.inspect}"
    lines = out.split("\n").length 
    assert lines >= 20, "Expecting more lines; got: #{out.inspect}"
  end

  def test_007_parser
    parse_tests = {
      # Loading/trailing blanks as well
      "kill 81 82 83"     => [:cmd_kill, "81 82 83"],
      "  kill 81 82 83"   => [:cmd_kill, "81 82 83"],
      "kill 81 82 83  "   => [:cmd_kill, "81 82 83"],
      "  kill 81 82 83  " => [:cmd_kill, "81 82 83"],
      "help"              => [:cmd_help, nil],
      "h"                 => [:cmd_help, nil],
      "version"           => [:cmd_version, nil],
      "v"                 => [:cmd_version, nil],
      "list views"        => [:cmd_list_views, nil],
      "lsv"               => [:cmd_list_views, nil],
      "new view foobar"   => [:cmd_new_view, "foobar"],
      "new post"          => [:cmd_new_post, nil],
      "p"                 => [:cmd_new_post, nil],
      "post"              => [:cmd_new_post, nil],
      "change view view2" => [:cmd_change_view, "view2"],
      "cv"                => [:cmd_change_view, nil], # 0-arity 
      "cv myview"         => [:cmd_change_view, "myview"],
      "list posts"        => [:cmd_list_posts, nil],
      "lsp"               => [:cmd_list_posts, nil],
      "list drafts"       => [:cmd_list_drafts, nil],
      "lsd"               => [:cmd_list_drafts, nil],
      "rm 999"            => [:cmd_remove_post, "999"],
      "kill 101 102 103"  => [:cmd_kill, "101 102 103"],
      "edit 104"          => [:cmd_edit_post, "104"],
      "ed 105"            => [:cmd_edit_post, "105"],
      "e 106"             => [:cmd_edit_post, "106"],
      "preview"           => [:cmd_preview, nil],
      "pre"               => [:cmd_preview, nil],
      "browse"            => [:cmd_browse, nil],
      "relink"            => [:cmd_relink, nil],
      "rebuild"           => [:cmd_rebuild, nil],
      "deploy"            => [:cmd_deploy, nil],
      "q"                 => [:cmd_quit, nil],
      "quit"              => [:cmd_quit, nil]
      # Later: too many/few params
    }

    parse_tests.each_pair do |cmd, expected|
      result = RuneBlog::REPL.choose_method(cmd)
      assert result == expected, "Expected #{expected.inspect} but got #{result.inspect}"
    end
  end
end

