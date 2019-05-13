<div float="left"><image src="raido.png"></div>
<p>

# runeblog
Runeblog is a blogging tool written in Ruby. It has these basic characteristics:
<p>

 * It is usable entirely from the command line
 * It publishes web pages as static HTML
 * So far, yes, like Jekyll
 * It's based on Livetext (highly extensible Ruby-based markup)
 * It has the concept of multiple "views" for a blog
The multiple views are in effect multiple blogs managed with the same backend.
<p>

## What is Livetext?
Livetext is a markup format that is a throwback to the old, old days of text 
formatters such as <font size=+1><tt>roff</tt></font> It's very flexible, and it is extensible <i>in Ruby</i>. 
<p>

It is far from mature or full-featured, but it is usable. Runeblog uses Livetext, 
along with some custom definitions, to try to ease the formatting of a blog entry.
<p>

## What are "views"?
Think of them as multiple separate blogs with the same backend. Why would you
want to do this? Maybe you wouldn't, but I do.
<p>

The purpose is to present different "faces" to different audiences. In my case,
my computing-related stuff would go into one view, and my hometown-related things
would go into another. There might be a view that only old friends or close friends
can see. There might be a view purely for reviews of music, books, and movies. 
<p>

But the important points are these:
 * _All the views will be managed the same way in the same place, and they will all share common data.
 * Any post can easily be included in a single view, in more than one, or in all of them.
 * Each view can have its own look and feel, and it can be linked/published separately from the others.
 * Each view can be hosted in a different location and/or a different server and domain
 * Any post can be in more than one view
## The `blog environment
There is a command-line tool called <font size=+1><tt>blog</tt></font>  which is a REPL (read-eval-print loop). 
Note that this tool is a curses-based environment (mainly so it can display menus
and such to the user).
<p>

The help message looks like this:
<p>

<pre>
  Commands:

     h, help           This message
     q, quit           Exit the program

     change view _view  Change current view
     new view          Create a new view
     list views        List all views available
     lsv               Same as: list views

     p, post           Create a new post
     new post          Same as post (create a post)
     lsp, list posts   List posts in current view
     lsd, list drafts  List all posts regardless of view

     rm _id             Remove a post
     edit _id           Edit a post

     preview           Look at current (local) view in browser
     browse            Look at current (deployed) view in browser

     relink            Regenerate index for all views  (MAY CHANGE)
     rebuild           Regenerate all posts and relink (MAY CHANGE)
     deploy            Deploy (current view)
</pre>
## Getting started
But when you first run the REPL, it checks for an existing blog under the <font size=+1><tt>.blog</tt></font>
directory. If it doesn't find one, it asks whether you want to create a new blog.
If you enter <font size=+1><tt>y</tt></font>  for yes, it creates a sort of "skeleton" with a single view
called <font size=+1><tt>est_view</tt></font>.
<p>

The next thing you should do is to create at least one view of your own. Use the
<font size=+1><tt>new view</tt></font> command for this.  
<p>

(new view)
<p>

(new post)
<p>

(preview)
<p>

(publishing one-time setup - server, ssh keys, etc.)
<p>

(publish)
<p>

(browse)
<p>

(and so on...)
<p>

*[To be continued]
<p>

## Changing the default templates
*TBD
<p>

## Basics of Livetext
*TBD
<p>

(bold, italics, etc.)
<p>

(common dot commands)
<p>

(predefined functions and variables)
<p>

## Runeblog-specific features (Liveblog)
*TBD
<p>

(dot commands)
<p>

(variables and functions)
<p>

## Defining your own features
(dot commands)
<p>

(variables and functions)
<p>

*TBD
<p>

## 
*TBD
<p>

## More later...
*TBD
<p>

