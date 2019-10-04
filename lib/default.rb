class RuneBlog::Default

# This will all become much more generic later.

def RuneBlog.post_template(num: 0, title: "No title", date: nil, view: "test_view", 
                       teaser: "No teaser", body: "No body", tags: ["untagged"], 
                       views: [], back: "javascript:history.go(-1)", home: "no url")
  log!(enter: __method__, args: [num, title, date, view, teaser, body, tags, views, back, home])
  viewlist = (views + [view.to_s]).join(" ")
  taglist = ".tags " + tags.join(" ")
<<-TEXT
.mixin liveblog
. ^ get rid of this later

.post #{num}
 
.title #{title}
.pubdate #{date}
.views #{viewlist}
#{taglist}
 
.teaser
#{teaser}
.end
#{body}
TEXT

end

end



