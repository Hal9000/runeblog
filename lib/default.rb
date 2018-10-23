class RuneBlog::Default

# This will all become much more generic later.

BlogHeader = <<-TEXT
<html>
<body>

<title>Ruby, Elixir, and More</title>

<table>
  <tr>
    <td>
        <img src=blog3a.jpg width=400 height=300>
    </td>
    <td>
      <h3>Yet another blog by Hal Fulton</h3>
      <br>
      <br>
      <b>Note</b>: I can never find a blogging engine I like! <br>
      For now, this will just be a set of static pages.
      <br>
      <br>
      If you want to comment, just <a href=mailto:rubyhacker@gmail.com>email me</a>.
    </td>
  </tr>
</table>

<hr>
TEXT

BlogTrailer = <<-TEXT
<!-- no blog trailer -->
TEXT

PostTemplate = <<-'TEXT'  # interpolate later
.mixin liveblog
 
.title #@title
.pubdate #@date
.views #@view
.tags 
 
.teaser
#{@meta.teaser}
.end
#{@meta.body}
TEXT


TeaserTemplate = <<-'TEXT'  # interpolate later
<html>

<body>

<script>
  window.fbAsyncInit = function() {
    FB.init({
      appId      : '1176481582378716',
      xfbml      : true,
      version    : 'v2.4'
    });
  };

  (function(d, s, id){
     var js, fjs = d.getElementsByTagName(s)[0];
     if (d.getElementById(id)) {return;}
     js = d.createElement(s); js.id = id;
     js.src = '//connect.facebook.net/en_US/sdk.js';
     fjs.parentNode.insertBefore(js, fjs);
   }(document, 'script', 'facebook-jssdk'));
</script>

    <!-- meta property='fb:admins' content='767352779' /> -->
    <meta property='og:url' content='http://rubyhacker.com/blog2/#{@meta.slug}.html'/>
    <meta property='og:type' content='article'/>
    <meta property='og:title' content='#{@meta.title}'/>
    <meta property='og:image' content='http://rubyhacker.com/blog2/blog3b.gif'/>
    <meta property='og:description' content='#{@meta.teaser}'/>

    <table bgcolor=#eeeeee cellspacing=5>
      <tr>
        <td valign=top>
          <br> <font size=+2 color=red>#{@meta.title.chomp}</font> <br> #{@meta.pubdate.chomp}
        </td>

        <td width=2% bgcolor=red></td>

        <td valign=top>
          <a href='https://twitter.com/share' 
          class='twitter-share-button' 
          data-text='#{@meta.title}' 
          data-url='#{'url'}' 
          data-via='hal_fulton' 
          data-related='hal_fulton'>Tweet</a>
             <script>!function(d,s,id){var js,fjs=d.getElementsByTagName(s)[0],p=/^http:/.test(d.location)?'http':'https';if(!d.getElementById(id)){js=d.createElement(s);js.id=id;js.src=p+'://platform.twitter.com/widgets.js';fjs.parentNode.insertBefore(js,fjs);}}(document, 'script', 'twitter-wjs');</script>
          <br>
          <a href='https://twitter.com/hal_fulton' class='twitter-follow-button' data-show-count='false'>Follow @hal_fulton</a>
          <script>!function(d,s,id){var js,fjs=d.getElementsByTagName(s)[0],p=/^http:/.test(d.location)?'http':'https';if(!d.getElementById(id)){js=d.createElement(s);js.id=id;js.src=p+'://platform.twitter.com/widgets.js';fjs.parentNode.insertBefore(js,fjs);}}(document, 'script', 'twitter-wjs');</script>

          <br>
            <div
              class='fb-like'
              data-share='true'
              data-width='450'
              data-show-faces='true'>
            </div>

          </td>

       </tr>
     </table>


<hr>

#{@meta.body}


<hr>
<a href="http://rubyhacker.com/blog2" style="text-decoration: none">Back</a> 
<a href="http://rubyhacker.com" style="text-decoration: none">Home</a>
TEXT

end
