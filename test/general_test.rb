$LOAD_PATH << "."
# require "test_helper"

require "minitest/autorun"
# require "minitest/fail_fast"

require 'runeblog'
require 'lib/repl'
require 'rubytext'

major, minor = RUBY_VERSION.split(".").values_at(0,1)
ver = major.to_i*10 + minor.to_i
abort "Need Ruby 2.4 or greater" unless ver >= 24

RubyText.start

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
    system("ruby test/make_blog.rb") if ARGV.first == "new"
    @blog = RuneBlog.new
  end

  # Note: "Bang" methods depend on the data subtree

  def test_001_cmd_help
#   puts __method__
    out = cmd_help(nil, true)
    assert out.is_a?(String), "Expected a string returned"
    lines = out.split("\n").length 
    assert lines > 15, "Expecting lengthy help message"
  end

  def test_002_cmd_version
#   puts __method__
    out = cmd_version(nil, true)
    assert out.is_a?(String), "Expected a string returned"
    lines = out
    assert lines =~ /\d+\.\d+\.\d+/m,
           "Couldn't find version number; found #{out.inspect}"
  end

  def test_003_list_views!
#   puts __method__
    out = cmd_list_views(nil, true)
    assert out.is_a?(String), "Expected a string returned"
    lines = out.split("\n").length 
    assert lines >= 2, "Expecting at least 2 lines"
  end
 
  def test_004_change_view!
#   puts __method__
    out = cmd_change_view(nil, true)  # no param, but testing
    assert out.is_a?(String), "Expected a string; got: #{out.inspect}"
    assert out =~ /alpha_view/m, "Expecting 'alpha_view' as default; got: #{out.inspect}"
  end

  def test_005_lsd!
#   puts __method__
    out = cmd_list_drafts(nil, true)
    assert out.is_a?(String), "Expected a string returned"
    nlines = out.split("\n").length 
    exp = 10
    assert nlines == exp, "Expecting #{exp} lines, got #{nlines}; #{show_lines(out)}"
  end

  def test_006_lsp!
#   puts __method__
    out = cmd_list_posts(nil, true)
    assert out.is_a?(String), "Expected a string returned; got: #{out.inspect}"
    lines = out.split("\n").length 
    assert lines == 6, "Expecting 6 lines; got #{lines.size}; #{show_lines(out)}"
  end

  def test_007_parser
#   puts __method__
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
      "browse"            => [:cmd_browse, nil],
      "relink"            => [:cmd_relink, nil],
      "rebuild"           => [:cmd_rebuild, nil],
      "publish"           => [:cmd_publish, nil],
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
#   puts __method__
    assert @blog.view.to_s == "alpha_view", "Current view wrong (#{@blog.view}, not alpha_view)"
  end

  def test_009_change_view!
#   puts __method__
    assert @blog.change_view("beta_view")
    assert @blog.view.to_s == "beta_view", "Current view wrong (#{@blog.view}, not beta_view)"
    assert @blog.change_view("alpha_view")
    assert @blog.view.to_s == "alpha_view", "Current view wrong (#{@blog.view}, not alpha_view)"
  end

  def test_010_accessors!
#   puts __method__
    sorted_views = @blog.views.map(&:to_s).sort
    assert sorted_views == ["alpha_view", "beta_view", "gamma_view", "test_view"], 
           "Got: #{sorted_views.inspect}"
  end

  def test_011_create_delete_view!
#   puts __method__
    @blog.create_view("anotherview")
    sorted_views = @blog.views.map(&:to_s).sort
    assert sorted_views == ["alpha_view", "anotherview", "beta_view", "gamma_view", "test_view"], 
           "After create: #{sorted_views.inspect}"
    @blog.delete_view("anotherview", true)
    sorted_views = @blog.views.map(&:to_s).sort 
    assert sorted_views == ["alpha_view", "beta_view", "gamma_view", "test_view"], 
           "After delete: #{sorted_views.inspect}"
  end

  def test_012_create_remove_post!
#   puts __method__
    @blog.change_view("beta_view")
    assert @blog.view.to_s == "beta_view", "Expected beta_view"
    nposts = @blog.posts.size 
    ndrafts = @blog.drafts.size 
    title = "Uninteresting title"
    num = @blog.create_new_post(title, true)

    assert @blog.posts.size == nposts + 1, "Don't see new post"
    @blog.remove_post(num)
    assert @blog.posts.size == nposts, "Failed to delete post"

    assert @blog.drafts.size == ndrafts + 1, "Don't see new draft"
    @blog.delete_draft(num)
    assert @blog.drafts.size == ndrafts, "Failed to delete draft"
    @blog.change_view("alpha_view")
  end

  def xtest_013_slug_tests
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
      meta = OpenStruct.new
      meta.title = real
      meta.num = 99
      result = @blog.make_slug(meta)[5..-1]  # Skip num (test_013...)
      assert result == fixed, "Case #{i}: expected: #{fixed.inspect}, got #{result.inspect}"
    end
  end

  def xtest_014_remove_nonexistent_post!
    @blog.change_view("alpha_view")
    out = cmd_remove_post(99, true)
    assert out =~ /Post 99 not found/, "Expected error about nonexistent post, got: #{out}"
  end

  def xtest_015_kill_multiple_posts!
    @blog.change_view("alpha_view")
    out = cmd_list_posts(nil, true)
    before = out.split("\n").length 
    cmd_kill("1  2 7", true)
    out = cmd_list_posts(nil, true)
    after = out.split("\n").length 
    expecting = before - 3
    assert after == expecting, "list_posts saw #{before} posts, now #{after} (not #{expecting})"
    @blog.undelete_post(1)
    @blog.undelete_post(2)
    @blog.undelete_post(7)
  end

if File.exist?("testing.publish")  # FIXME!!!

  def xtest_016_can_publish
#   puts __method__
    x = OpenStruct.new
    x.user, x.server, x.docroot, x.docroot, x.path, x.proto = 
      "root", "rubyhacker.com", "/var/www", "whatever", "http"
    dep = RuneBlog::Publishing.new(x)
    result = dep.remote_login?
    assert result == true, "Valid login doesn't work"
    result = dep.remote_permissions?
    assert result == true, "Valid mkdir doesn't work"
  end

  def xtest_017_cannot_publish_wrong_user
#   puts __method__
    x = OpenStruct.new
    x.user, x.server, x.docroot, x.docroot, x.path, x.proto = 
      "bad_user", "rubyhacker.com", "/var/www", "whatever", "http"
    dep = RuneBlog::Publishing.new(x)
    result = dep.remote_login?
    assert result.nil?, "Expected to detect login error (bad user)"
  end

  def xtest_018_cannot_publish_bad_server
#   puts __method__
    x = OpenStruct.new
    x.user, x.server, x.docroot, x.docroot, x.path, x.proto = 
      "root", "nonexistent123.com", "/var/www", "whatever", "http"
    dep = RuneBlog::Publishing.new(x)
    result = dep.remote_login?
    assert result.nil?, "Expected to detect login error (bad server)"
  end

end  # conditional tests

  def xtest_019_exception_existing_blog
#   puts __method__
    assert_raises(BlogAlreadyExists) { RuneBlog.create_new_blog_repo }
  end

  def xtest_020_exception_missing_blog_accessor
#   puts __method__
    save = RuneBlog.blog
    RuneBlog.blog = nil
    assert_raises(NoBlogAccessor) { RuneBlog::Post.load(1) }
    RuneBlog.blog = save
  end

  def xtest_021_exception_cant_assign_view
#   puts __method__
    assert_raises(CantAssignView) { @blog.view = 99 }
  end

  def xtest_022_exception_no_such_view
#   puts __method__
    assert_raises(NoSuchView) { @blog.view = 'not_a_view_name' }
  end

  def xtest_023_exception_view_already_exists
#   puts __method__
    assert_raises(ViewAlreadyExists) { @blog.create_view('alpha_view') }
  end

  def xtest_024_exception_livetext_error   # FIXME Doesn't work! Change Livetext
#   puts __method__
    testfile = "testfile.lt3"
    path = @blog.root + "/drafts/" + testfile
    cmd = "echo .no_such_command > #{path}"
    system(cmd)
#   system("ls -l #{path}")
    save = STDERR
    STDERR.reopen("/dev/null")
    assert_raises(LivetextError) { @blog.process_post(testfile) }
    STDERR.reopen(save)
    File.rm(path)
  end

  # later tests...
  # new view asks for publishing info and writes it
  #   (how to mimic user input? test some other way?)

end

