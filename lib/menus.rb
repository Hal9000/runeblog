
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


#   dir = @blog.view.dir/"themes/standard/"

std = "themes/standard"
data = "."    # CHANGED

Menu.top_config = {
    "View: generator"                     => edit("#{std}/blog/generate.lt3"),
    "   HEAD info"                        => edit("#{std}/blog/head.lt3"),
    "   Layout "                          => edit("#{std}/blog/index.lt3"),
    "   Recent-posts entry"               => edit("#{std}/blog/post_entry.lt3"),
    "   Banner: Description"              => edit("#{std}/banner/banner.lt3"),
    "      Navbar"                        => edit("#{std}/navbar/navbar.lt3"),
#   "      Text portion"                  => edit("#{std}/banner/top.lt3"),
    "Generator for a post"                => edit("#{std}/post/generate.lt3"),
    "   HEAD info for post"               => edit("#{std}/post/head.lt3"),
    "   Content for post"                 => edit("#{std}/post/index.lt3"),
    "Variables (general)"                 => edit("#{data}/global.lt3"),
    "   View-specific"                    => edit("settings/view.txt"),
    "   Recent posts"                     => edit("settings/recent.txt"),
    "   Publishing"                       => edit("settings/publish.txt"),
    "Configuration: enable/disable"       => edit("settings/features.txt"),
    "   Reddit"                           => edit("config/reddit/credentials.txt"),
    "   Facebook"                         => edit("config/facebook/credentials.txt"),
    "   Twitter"                          => edit("config/twitter/credentials.txt"),
    "Global CSS"                          => edit("#{std}/etc/blog.css.lt3"),
    "External JS/CSS (Bootstrap, etc.)"   => edit("/etc/externals.lt3") 
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

