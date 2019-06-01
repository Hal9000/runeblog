class RuneBlog::Default

# This will all become much more generic later.


def RuneBlog.post_template(title: "No title", date: nil, view: "test_view", 
                       teaser: "No teaser", body: "No body", tags: ["untagged"], 
                       views: [], back: "javascript:history.go(-1)", home: "no url")
  viewlist = (views + [view.to_s]).join(" ")
  taglist = ".tags " + tags.join(" ")
<<-TEXT
.mixin liveblog
. ^ get rid of this later
 
.title #{title}
.pubdate #{date}
.views #{viewlist}
#{taglist}
 
.teaser
#{teaser}
.end
#{body}
<hr>
<a href='#{back}' style='text-decoration: none'>Back</a>
<br>
<a href='#{home}' style='text-decoration: none'>Home</a>
TEXT

end

end



