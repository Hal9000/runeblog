
require 'ostruct'
require 'rubytext'
require 'repl'

Menu = OpenStruct.new

notimp = proc { RubyText.splash("Not implemented yet") }

top_about  = proc { RubyText.splash("RuneBlog v #{RuneBlog::VERSION}") }
top_help   = proc { RubyText.splash(RuneBlog::REPL::Help.gsub(/[{}]/, " ")) }

Menu.top_build  = { 
     Rebuild: proc { cmd_rebuild },
     Preview: proc { cmd_preview },
     Publish: proc { cmd_publish },
     Browse:  proc { cmd_browse }, 
     ssh:     proc { cmd_ssh }
  }

Menu.top_items = {
    About:  top_about,
    Views:  notimp,
    Build:  proc { STDSCR.menu(items: Menu.top_build) },
    Config: notimp,
    Help:   top_help,
    Quit:   proc { cmd_quit }
  }

def show_top_menu
  STDSCR.topmenu(items: Menu.top_items)
end

# about_items 


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

#   def cmd_config
#     hash = {"Variables (general)"                 => "global.lt3",
#             "   View-specific"                    => "../../settings/view.txt",
#             "   Recent posts"                     => "../../settings/recent.txt",
#             "   Publishing"                       => "../../settings/publish.txt",
#             "Configuration: enable/disable"       => "../../settings/features.txt",
#             "   Reddit"                           => "../../config/reddit/credentials.txt",
#             "   Facebook"                         => "../../config/facebook/credentials.txt",
#             "   Twitter"                          => "../../config/twitter/credentials.txt",
#             "View: generator"                     => "blog/generate.lt3",
#             "   HEAD info"                        => "blog/head.lt3",
#             "   Layout "                          => "blog/index.lt3",
#             "   Recent-posts entry"               => "blog/post_entry.lt3",
#             "   Banner: Description"              => "blog/banner.lt3",
#             "      Text portion"                  => "banner/top.lt3",
#             "Generator for a post"                => "post/generate.lt3",
#             "   HEAD info for post"               => "post/head.lt3",
#             "   Content for post"                 => "post/index.lt3",
#             "Global CSS"                          => "etc/blog.css.lt3",
#             "External JS/CSS (Bootstrap, etc.)"   => "/etc/externals.lt3"
#            }
# 
#     dir = @blog.view.dir/"themes/standard/"
#     num, target = STDSCR.menu(title: "Edit file:", items: hash)
#     edit_file(dir/target)
#   end
# 
