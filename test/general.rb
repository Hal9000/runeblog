$LOAD_PATH << "."

require "minitest/autorun"

require 'lib/repl'

class TestREPL < Minitest::Test
  include RuneBlog::REPL

  def show_lines(text)
    lines = text.split("\n")
    str = "#{lines.size} lines\n"
    lines.each {|line| str << "  #{line.inspect}\n" }
    str
  end

  def setup
    # To be strictly correct in testing (though slower),
    #   run make_blog here.
    @blog = RuneBlog.new
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
    assert @blog.view.to_s == "alpha_view", "Current view wrong (#{@blog.view}, not alpha_view)"
  end

  def test_009_change_view!
    assert @blog.change_view("beta_view")
    assert @blog.view.to_s == "beta_view", "Current view wrong (#{@blog.view}, not beta_view)"
    assert @blog.change_view("alpha_view")
    assert @blog.view.to_s == "alpha_view", "Current view wrong (#{@blog.view}, not alpha_view)"
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
    nposts = @blog.posts.size 
    ndrafts = @blog.drafts.size 
    meta = OpenStruct.new
    meta.title = "Uninteresting title"
    num = @blog.create_new_post(meta, true)

    assert @blog.posts.size == nposts + 1, "Don't see new post"
    @blog.remove_post(num)
    assert @blog.posts.size == nposts, "Failed to delete post"

    assert @blog.drafts.size == ndrafts + 1, "Don't see new draft"
    @blog.delete_draft(num)
    assert @blog.drafts.size == ndrafts, "Failed to delete draft"
    @blog.change_view("alpha_view")
  end

  def test_013_slug_tests
    hash = { "abcxyz"      => "abcxyz",      # 0-based
             "abc'xyz"     => "abcxyz",
             'abc"xyz'     => "abcxyz",
             '7%sol'       => "7sol",
             "only a test" => "only-a-test",
             "abc  xyz"    => "abc--xyz",    # change this behavior?
             "ABCxyZ"      => "abcxyz",
           }
    hash.each_pair.with_index do |keys, i|
      real, fixed = *keys
      result = @blog.make_slug(real)[1][5..-1]  # weird? returns [99, "0099-whatever"]
      assert result == fixed, "Case #{i}: expected: #{fixed.inspect}, got #{result.inspect}"
    end
  end

  def test_014_remove_nonexistent_post!
    @blog.change_view("alpha_view")
    out = cmd_remove_post(99)
    assert out =~ /Post 99 not found/, "Expected error about nonexistent post, got: #{out}"
  end

  def test_015_kill_multiple_posts!
    @blog.change_view("alpha_view")
    out = cmd_list_posts(nil)
    before = out.split("\n").length 
    out = cmd_kill("1  2 7")
    out = cmd_list_posts(nil)
    after = out.split("\n").length 
    assert after == before - 3, "list_posts saw #{before} posts, now #{after} (not #{before-3})"
    system("ruby test/make_blog.rb")   # This is hellish, I admit
  end

  def test_016_can_deploy
    x = OpenStruct.new
    x.user, x.server, x.docroot, x.docroot, x.path, x.proto = 
      "root", "rubyhacker.com", "/var/www", "whatever", "http"
    dep = RuneBlog::Deployment.new(x)
    result = dep.remote_login?
    assert result == true, "Valid login doesn't work"
    result = dep.remote_permissions?
    assert result == true, "Valid mkdir doesn't work"
  end

  def test_017_cannot_deploy_wrong_user
    x = OpenStruct.new
    x.user, x.server, x.docroot, x.docroot, x.path, x.proto = 
      "bad_user", "rubyhacker.com", "/var/www", "whatever", "http"
    dep = RuneBlog::Deployment.new(x)
    result = dep.remote_login?
    assert result.nil?, "Expected to detect login error (bad user)"
  end

  def test_018_cannot_deploy_bad_server
    x = OpenStruct.new
    x.user, x.server, x.docroot, x.docroot, x.path, x.proto = 
      "root", "nonexistent123.com", "/var/www", "whatever", "http"
    dep = RuneBlog::Deployment.new(x)
    result = dep.remote_login?
    assert result.nil?, "Expected to detect login error (bad server)"
  end

  # later tests...
  # new view asks for deployment info and writes it
  #   (how to mimic user input? test some other way?)

end
