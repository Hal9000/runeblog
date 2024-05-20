
require 'ostruct'
require 'rubytext'
require 'repl'

Menu = OpenStruct.new

def edit(str)
  proc { edit_file(str) }
end

notimp = proc { RubyText.splash("Not implemented yet") }

top_about  = proc { RubyText.splash("RuneBlog v #{RuneBlog::VERSION}") }
top_help   = proc { RubyText.splash(RuneBlog::REPL::Help.gsub(/[{}]/, " ")) }

def edit_blog_generate
  edit_file("#@std/blog/generate.lt3")
end

def edit_blog_head
  edit_file("#@std/blog/head.lt3")
end

def edit_blog_index
  edit_file("#@std/blog/index.lt3")
end

def edit_post_entry
  edit_file("#@std/blog/post_entry.lt3")
end

def edit_blog_banner
  edit_file("#@std/banner/banner.lt3")
end

def edit_blog_navbar
  edit_file("#@std/navbar/navbar.lt3")
end

def edit_post_generate
  edit_file("#@std/post/generate.lt3")
end

def edit_post_head
  edit_file("#@std/post/head.lt3")
end

def edit_post_index
  edit_file("#@std/post/index.lt3")
end

def edit_view_global
  # CHANGED redefining "global" location
  edit_file("global.lt3")
end

def edit_settings_view
  edit_file("settings/view.txt")
end

def edit_settings_recent
  edit_file("settings/recent.txt")
end

def edit_settings_publish
  edit_file("settings/publish.txt")
end

def edit_settings_features
  edit_file("settings/features.txt")
end

def edit_config_reddit
  edit_file("config/reddit/credentials.txt")
end

def edit_config_facebook
  edit_file("config/facebook/credentials.txt")
end

def edit_config_twitter
  edit_file("config/twitter/credentials.txt")
end

def edit_etc_blog_css
  edit_file("#@std/etc/blog.css.lt3")
end

def edit_etc_externals
  edit_file("#@std/etc/externals.lt3") 
end

#   dir = @blog.view.dir/"themes/standard/"

@std  = "themes/standard"

Menu.top_config = {
    "View: generator"                     => proc { edit_blog_generate },
    "   HEAD info"                        => proc { edit_blog_head },
    "   Layout "                          => proc { edit_blog/index },
    "   Recent-posts entry"               => proc { edit_post_entry },
    "   Banner: Description"              => proc { edit_banner },
    "      Navbar"                        => proc { edit_navbar },
    "Generator for a post"                => proc { edit_post_generate },
    "   HEAD info for post"               => proc { edit_post_head },
    "   Content for post"                 => proc { edit_post_index },
    "Variables (general!)"                => proc { edit_view_global },
    "   View-specific"                    => proc { edit_settings_view },
    "   Recent posts"                     => proc { edit_settings_recent },
    "   Publishing"                       => proc { edit_settings_publish },
    "Configuration: enable/disable"       => proc { edit_settings_features },
    "   Reddit"                           => proc { edit_config_reddit },
    "   Facebook"                         => proc { edit_config_facebook },
    "   Twitter"                          => proc { edit_config_twitter },
    "Global CSS"                          => proc { edit_etc_blog_css },
    "External JS/CSS (Bootstrap, etc.)"   => proc { edit_etc_externals }
  }
  
Menu.top_build  = { 
     Rebuild: proc { cmd_rebuild },
     Preview: proc { cmd_preview },
     Publish: proc { cmd_publish },
     Browse:  proc { cmd_browse }, 
     ssh:     proc { cmd_ssh }
  }

Menu.top_items = {
    About:  top_about,
#   Views:  notimp,
    Build:  proc { STDSCR.menu(items: Menu.top_build) },
    Config: proc { STDSCR.menu(items: Menu.top_config) },
    Help:   top_help,
    Quit:   proc { cmd_quit }
  }

def show_top_menu
  r, c = STDSCR.rc
  STDSCR.topmenu(items: Menu.top_items)
  STDSCR.go r-1, 0
end

=begin
   About (version)
   Help
   Views
     New view
     (select)
   Posts
     New post
     (select)
   Drafts
     (select) hmm...
   Widgets
     (select) 
   Assets

   Build
     rebuild  
     preview  
     publish  
     browse   
     ssh      

     quit         
=end

    {

     "tags"              => :cmd_tags,
     "import"            => :cmd_import,

     "config"            => :cmd_config,

     "install $widget"   => :cmd_install_widget,
     "enable $widget"    => :cmd_enable_widget,
     "disable $widget"   => :cmd_disable_widget,
     "update $widget"    => :cmd_update_widget,
     "manage $widget"    => :cmd_manage,

     "list assets"       => :cmd_list_assets,
     "lsa"               => :cmd_list_assets,

     "pages"             => :cmd_pages,

     "delete >postid"    => :cmd_remove_post,
     "undel $postid"     => :cmd_undelete_post,

     "edit $postid"      => :cmd_edit_post,
     "ed $postid"        => :cmd_edit_post,
     "e $postid"         => :cmd_edit_post,

   }

