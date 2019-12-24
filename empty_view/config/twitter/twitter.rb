class Livetext::Functions

# Needed for Twitter??

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

  def twitter_share(title, url)
    name = _var("twitter.user")
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
    name = _var("twitter.user")
    <<~HTML
      <a href='https://twitter.com/#{name}' class='twitter-follow-button' data-show-count='false'>Follow @#{name}</a>
    HTML
  end

end
