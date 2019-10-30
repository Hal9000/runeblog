<div float="left" align="left">
<img src="raido.png" width="196" height="275" align="left"></img>
</div>
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
## The `[blog] environment
There is a command-line tool called <font size=+1><tt>blog</tt></font>  which is a REPL (read-eval-print loop). 
Note that this tool is a curses-based environment (mainly so it can display menus
and such to the user).
<p>

The help message looks like this:
<p>

<pre>
  <b>Basics:</b>                                         <b>Views:</b>
  -------------------------------------------     -------------------------------------------
  <b>h, help</b>           This message                  <b>change view VIEW</b>  Change current view
  <b>q, quit</b>           Exit the program              <b>cv VIEW</b>           Change current view
  <b>v, version</b>        Print version information     <b>new view</b>          Create a new view
  <b>clear</b>             Clear screen                  <b>list views</b>        List all views available
                                                  <b>lsv</b>               Same as: list views
<br>
  <b>Posts:</b>                                          <b>Advanced:</b>
  -------------------------------------------     -------------------------------------------
  <b>p, post</b>           Create a new post             <b>config</b>            Edit various system files
  <b>new post</b>          Same as p, post               <b>customize</b>         (BUGGY) Change set of tags, extra views
  <b>lsp, list posts</b>   List posts in current view    <b>preview</b>           Look at current (local) view in browser
  <b>lsd, list drafts</b>  List all drafts (all views)   <b>browse</b>            Look at current (published) view in browser
  <b>delete ID [ID...]</b> Remove multiple posts         <b>rebuild</b>           Regenerate all posts and relink
  <b>undelete ID</b>       Undelete a post               <b>publish</b>           Publish (current view)
  <b>edit ID</b>           Edit a post                   <b>ssh</b>               Login to remote server
  <b>import ASSETS</b>     Import assets (images, etc.)  <b>manage WIDGET</b>     Manage content/layout of a widget
</pre>
## Getting started
But when you first run the REPL, it checks for an existing blog repository under 
the <font size=+1><tt>.blogs</tt></font> directory. If it doesn't find one, it asks whether you want to create 
a new blog repo. Enter <font size=+1><tt>y</tt></font>  for yes.
<p>

You'll then enter the editor (vim for now) to add configuration info to the <font size=+1><tt>global.lt3</tt></font>  file.
<p>

<pre><b>FIXME add menu screenshot here</b></pre>
<pre><b>FIXME add vim screenshot here</b></pre>
<p>

The next thing you should do is to create at least one view of your own. Use the
`[new view] command for this. Note that the current view is displayed as part of the prompt.
<p>

<pre>
<b>[no view]</b> new view mystuff<br>
<b>[mystuff]</b>
</pre>
<p>

To create a new post, use the <font size=+1><tt>new post</tt></font> command (also abbreviated <font size=+1><tt>post</tt></font>  or simply <font size=+1><tt>p</tt></font>). You will be
prompted for a title:
<p>

<pre>
<b>[around_austin]</b> new post<br>
<b>Title:</b> This is my first post
</pre>
<p>

Then you'll be sent into the editor (currently vim but can be others):
<p>

<pre><b>FIXME add example here</b></pre>
<p>

<pre>
<b>FIXME wizard?</b>
(publishing one-time setup - server, ssh keys, etc.)
preview...
publish...
browse...
(and so on)
</pre>
<p>

*[To be continued]
<p>

## Customizing the default templates and configuration
You can use the <font size=+1><tt>config</tt></font>  command to choose a file to edit.
<p>

<pre><b>FIXME add screenshot here</b></pre>
<p>

The meaning and interaction of these files will be explained later. <b>FIXME</b>
<p>

When you make changes, <font size=+1><tt>rebuild</tt></font>  will detect these and regenerate whatever files
are needed.
<p>

## The directory structure for a view
<pre><b>FIXME add details here</b></pre>
<p>

<p>

## Basics of Livetext
*TBD
<p>

(bold, italics, etc.)
<p>

(common dot commands)
<pre>
  .debug
  .say
  .nopara
  .quit
  indented dot-commands
</pre>
<p>

(external files)
<pre>
  .mixin
  .include
  .copy
  .seek
</pre>
<p>

(predefined functions and variables)
<pre>
  $File
  $\[date is undefined]
  etc.
</pre>
<p>

## Runeblog-specific features (Liveblog)
*TBD
<p>

(dot commands - the basics)
<pre>
  .mixin liveblog
  .post
  .title
  .views
  .tags
  .teaser
</pre>
<p>

(dot commands - more advanced)
<pre>
  .image
  .inset
  .dropcap
  .pin
</pre>
<p>

(variables and functions)
<pre>
  $view, etc.
  $\[date is undefined], $\[link is undefined], etc.
</pre>
<p>

<p>

## Defining your own features
(dot commands, variables, functions)
<pre>
  .def/.end
  .set
  .heredoc
  .variables
  .func
</pre>
<p>

(defining these in Ruby)
<p>

<p>

## More topics
(meta tags, etc.)
(CSS)
<p>

(widgets) 
<pre>
  pages
  links 
  pinned
  faq
  sitemap
  news
  etc.
</pre>
<p>

(banner and navbar)
<p>

(creating your own widgets)
<p>

(special tags coming "soon")
<pre>
  github, gitlab, gist
  wikipedia
  youtube, vimeo
  twitter, instagram
  etc.
</pre>
<p>

<p>

*TBD
<p>

## More later...
*TBD
<p>

