app_name   = "raido1"
app_client = "rAyZILgqGB7uHQ"
secret     = "0CqLXyFu6ABb1MrErWRsB7Bo-i8"

# https://www.reddit.com/api/v1/authorize?client_id=rAyZILgqGB7uHQ&response_type=code&state=abc237def&redirect_uri=http%3A%2F%2Frubyhacker.com&duration=permanent&scope=identity%20edit%20flair%20history%20modconfig%20modflair%20modlog%20modposts%20modwiki%20mysubreddits%20privatemessages%20read%20report%20save%20submit%20subscribe%20vote%20wikiedit%20wikiread

require 'net/http'
require 'uri'
require 'json'

=begin
get_token = URI.parse("https://www.reddit.com/api/v1/access_token")
data = {
         grant_type: authorization_code
         code=CODE
         redirect_uri=URI
       }
=end

uri = URI.parse("http://reddit.com/api/submit")

header = {'Content-Type': 'text/json'}
data = {
         sr:   "RubyElixirEtc",
         kind: "link",
         title: "[Post] This is my title",
         url:  "http://rubyhacker.com/around_austin/permalink/the-graffiti-wall.html"
       }

# Create the HTTP objects
http = Net::HTTP.new(uri.host, uri.port)
request = Net::HTTP::Post.new(uri.request_uri, header)
request.body = user.to_json

# Send the request
response = http.request(request)


