class RuneBlog::Command 
  Patterns = 
    {"help"              => :cmd_help, 
     "h"                 => :cmd_help,

     "version"           => :cmd_version,
     "v"                 => :cmd_version,

     "list views"        => :cmd_list_views, 
     "lsv"               => :cmd_list_views, 

     "new view $name"    => :cmd_new_view,

     "new post"          => :cmd_new_post,
     "p"                 => :cmd_new_post,
     "post"              => :cmd_new_post,

     "change view $name" => :cmd_change_view,
     "cv $name"          => :cmd_change_view,
     "cv"                => :cmd_change_view,  # 0-arity must come second

     "list posts"        => :cmd_list_posts,
     "lsp"               => :cmd_list_posts,

     "list drafts"       => :cmd_list_drafts,
     "lsd"               => :cmd_list_drafts,

     "rm $postid"        => :cmd_remove_post,

     "edit $postid"      => :cmd_edit_post,
     "ed $postid"        => :cmd_edit_post,
     "e $postid"         => :cmd_edit_post,

     "preview"           => :cmd_preview,

     "pre"               => :cmd_preview,

     "browse"            => :cmd_browse,

     "relink"            => :cmd_relink,

     "rebuild"           => :cmd_rebuild,

     "deploy"            => :cmd_deploy,

     "q"                 => :cmd_quit,
     "quit"              => :cmd_quit
   }
  
  Regexes = {}
  Patterns.each_pair do |pat, meth|
    rx = "^" + pat
    rx.gsub!(/ /, " +")
    rx.gsub!(/\$(\w+) */) { " *(?<#{$1}>\\w+)" }
    rx << "$"
    rx = Regexp.new(rx)
    Regexes[rx] = meth
  end

  def self.choose_method(cmd)
    found = nil
    params = []
    Regexes.each_pair do |rx, meth|
      m = cmd.match(rx)
# puts "#{rx} =~ #{cmd.inspect}  --> #{m.to_a.inspect}"
      result = m ? m.to_a : nil
      next unless result
      found = meth
      params = m[1..-1]
    end
    meth = found || :cmd_INVALID
    params = cmd if meth == :cmd_INVALID
    [meth, params]
  end
end

