# runeblog
Runeblog is a blogging tool written in Ruby. It has these basic characteristics:
<p>

 * It is usable entirely from the command line
 * It publishes web pages as static HTML
 * So far, yes, like Jekyll
 * It's based on Livetext (highly extensible Ruby-based markup)
 * It has the concept of multiple "views" for a blog
## What is Livetext?
Livetext is a markup format that is a throwback to the old, old days of text 
formatters such as nroff. It's very flexible, and it is extensible <i>in Ruby</i>. 
<p>

It isn't yet full-featured, but it is usable. Runeblog uses Livetext, along 
with some custom definitions, to try to ease the formatting of a blog entry.
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
 * <i>All</i> the views will be managed the same way in the same place, and they will all share common data.
 * Any post can easily be included in a single view, in more than one, or in all of them.
 * Each view can have its own look and feel, and it can be linked/published separately from the others.
 * Each view can be hosted in a different location and/or a different server and domain
## The `blog environment
There is a command-line tool called <tt>blog</tt> which is a REPL (read-eval-print loop). 
The help message looks like this:
<p>

<pre>
  Commands:

     h, help           This message
     q, quit           Exit the program

     change view <i>view</i> Change current view
     new view          Create a new view
     list views        List all views available
     lsv               Same as: list views

     p, post           Create a new post
     new post          Same as post (create a post)
     lsp, list posts   List posts in current view
     lsd, list drafts  List all posts regardless of view

     rm <i>id</i>             Remove a post
     edit <i>id</i>           Edit a post

     open              Look at current (local) view in browser
     open remote       Look at current (deployed) view in browser

     relink            Regenerate index for all views
     rebuild           Regenerate all posts and relink
     deploy            Deploy (current view)
</pre>
## More later...
<b>To be continued</b>
<p>

<p>

