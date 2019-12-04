
class Livetext::Functions

  def facebook_init
    fb_appid = _var("facebook.appid")
    <<~HTML
        window.fbAsyncInit = function() {
          FB.init({
            appId      : '#{fb_appid}',
            xfbml      : true,
            version    : 'v2.4'
          });
        };
    HTML
  end

=begin
<!-- Needed:  btw what is 'content'?
  <meta property='fb:admins' content='767352779'/> 
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
           data-share='true'
           data-width='450'
           data-show-faces='true'>
      </div>
    HTML
  end

  def twitter_share
    name, title, url = "", "", ""  # FIXME
    <<~HTML
      <a href='https://twitter.com/share' 
         class='twitter-share-button' 
         data-text='#{title}' 
         data-url='#{url}' 
         data-via='#{name}' 
         data-related='#{name}'>Tweet</a>
    HTML
  end

  def twitter_follow
    name = "hal_fulton"   # FIXME
    <<~HTML
      <a href='https://twitter.com/#{name}' class='twitter-follow-button' data-show-count='false'>Follow @#{name}</a>
    HTML
  end

end
