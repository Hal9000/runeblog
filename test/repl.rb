$LOAD_PATH << "."

require "minitest/autorun"

require 'lib/repl'

class TestREPL < Minitest::Test
  include RuneBlog::REPL

  def make_post(x, title)
    meta = OpenStruct.new
    meta.title = title
    num = x.create_new_post(meta, true)
  end

  def show_lines(text)
    lines = text.split("\n")
    str = "#{lines.size} lines\n"
    lines.each {|line| str << "  #{line.inspect}\n" }
    str
  end

  def setup
    system("rm -rf data_test")
#   system("tar xvf data_test.tar 2>/dev/null")
    RuneBlog.create_new_blog(Dir.pwd + "/data_test")
    x = RuneBlog.new
    x.create_view("alpha_view")
    x.create_view("beta_view")
    x.create_view("gamma_view")

    x.change_view("alpha_view")    # 1 2 7 8 9 
    make_post(x, "Post number 1")
    make_post(x, "Post number 2")
    x.change_view("beta_view")     # 3 5 6
    make_post(x, "Post number 3")
    x.change_view("gamma_view")    # 4 10
    make_post(x, "Post number 4")
    x.change_view("beta_view")
    make_post(x, "Post number 5")
    make_post(x, "Post number 6")
    x.change_view("alpha_view")
    make_post(x, "Post number 7")
    make_post(x, "Post number 8")
    make_post(x, "Post number 9")
    x.change_view("gamma_view")
    make_post(x, "Post number 10")
    x.change_view("alpha_view")
    @blog = x
  end

  # Note: "Bang" methods depend on the data_test subtree

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

  def test_003_list_views!
    out = cmd_list_views(nil)
    assert out.is_a?(String), "Expected a string returned"
    lines = out.split("\n").length 
    assert lines >= 2, "Expecting at least 2 lines"
  end

  def test_004_change_view!
    out = cmd_change_view(nil)  # no param
    assert out.is_a?(String), "Expected a string; got: #{out.inspect}"
    assert out =~ /alpha_view/m, "Expecting 'alpha_view' as default; got: #{out.inspect}"
  end

  def test_005_lsd!
    out = cmd_list_drafts(nil)
    assert out.is_a?(String), "Expected a string returned"
    lines = out.split("\n").length 
    assert lines == 11, "Expecting 11 lines; got #{show_lines(out)}"
  end

  def test_006_lsp!
    out = cmd_list_posts(nil)
    assert out.is_a?(String), "Expected a string returned; got: #{out.inspect}"
    lines = out.split("\n").length 
    assert lines == 7, "Expecting 7 lines; got #{show_lines(out)}"
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
      "change view beta_view" => [:cmd_change_view, "beta_view"],
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

  def test_008_current_view!
    assert @blog.view.to_s == "alpha_view", "Current view seems wrong (#{@blog.view}, not alpha_view)"
  end

  def test_009_change_view!
    assert @blog.change_view("beta_view")
    assert @blog.view.to_s == "beta_view", "Current view seems wrong (#{@blog.view}, not beta_view)"
  end

  def test_010_accessors!
    sorted_views = @blog.views.map(&:to_s).sort
    assert sorted_views == ["alpha_view", "beta_view", "gamma_view"], 
           "Got: #{sorted_views.inspect}"
  end

  def test_011_create_delete_view!
    @blog.create_view("anotherview")
    sorted_views = @blog.views.map(&:to_s).sort
    assert sorted_views == ["alpha_view", "anotherview", "beta_view", "gamma_view"], 
           "After create: #{sorted_views.inspect}"
    @blog.delete_view("anotherview", true)
    sorted_views = @blog.views.map(&:to_s).sort 
    assert sorted_views == ["alpha_view", "beta_view", "gamma_view"], 
           "After delete: #{sorted_views.inspect}"
  end

  def test_012_create_remove_post!
    @blog.change_view("beta_view")
    assert @blog.view.to_s == "beta_view", "Expected beta_view"
    before = @blog.posts.size 
    meta = OpenStruct.new
    meta.title = "Uninteresting title"
    num = @blog.create_new_post(meta, true)
    assert @blog.posts.size == before + 1, "Don't see new post"
    @blog.remove_post(num)
    assert @blog.posts.size == before, "Failed to delete post"
  end

  def test_013_kill_posts!
  end
end

