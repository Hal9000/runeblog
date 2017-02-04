runeblog
--------
Runeblog is a blogging tool written in Ruby. It has these basic characteristics:
 - It is usable entirely from the command line
 - It publishes web pages as static HTML
 - So far, yes, like Jekyll
 - It's based on Livetext (highly extensible Ruby-based markup)
 - It has the concept of multiple "views" for a blog

What is Livetext?
-----------------
Livetext is a markup format that is a throwback to the old, old days of text 
formatters such as nroff. It is very flexible, and it is extensible _in Ruby_. 
It is not yet full-featured, but it is usable. Runeblog uses Livetext, along 
with some custom definitions, to try to ease the formatting of a blog entry.

What are "views"?
-----------------
Think of them as multiple separate blogs with the same backend. Why would you
want to do this? Maybe you wouldn't, but I do.

The purpose is to present different "faces" to different audiences. In my case,
my computing-related stuff would go into one view, and my hometown-related things
would go into another. There might be a view that only old friends or close friends
can see. There might be a view purely for reviews of music, books, and movies. 

But the important points are these:
 - _All_ the views will be managed the same way in the same place, and they will all share common data.
 - Any post can easily be included in a single view, in more than one, or in all of them.
 - Each view can have its own look and feel, and it can be linked/published separately from the others.

More later...
-------------
To be continued

