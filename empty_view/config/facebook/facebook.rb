class Livetext::Functions

  def facebook_init
    fb_appid = _var("facebook.appid")
    xfbml    = _var("facebook.xfbml")
    ver      = _var("facebook.version")
    width    = _var("facebook.width")
    share    = _var("facebook.share")
    faces    = _var("facebook.faces")
    <<~HTML
        window.fbAsyncInit = function() {
          FB.init({
            appId      : '#{fb_appid}',
            xfbml      : #{xfbml},
            version    : '#{ver}'
          });
        };
    HTML
  end

=begin
<!-- Needed: 
  <meta property='fb:admins' content='$facebook.admins'/> 
  <meta property='og:url' content='http://rubyhacker.com/blog2/#{slug}.html'/>
  <meta property='og:type' content='article'/>
  <meta property='og:title' content='#{title}'/>
  <meta property='og:image' content='http://rubyhacker.com/blog2/blog3b.gif'/>
  <meta property='og:description' content='#{teaser}'/>
-->
=end

  def facebook_likes
    <<~HTML
      <div class='fb-like'
           data-share='#{share}'
           data-width='#{width}'
           data-show-faces='#{faces}'>
      </div>
    HTML
  end

end
