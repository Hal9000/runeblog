
import re
import praw

f = open("reddit/credentials.txt", "r")
lines = f.readlines()
f.close()

dict = {}
for line in lines:
  data = re.split(" +", line)
  dict[data[0]] = data[1].rstrip()


reddit = praw.Reddit(user_agent    = dict['user_agent'],
                     client_id     = dict['client_id'],
                     client_secret = dict['client_secret'],
                     username      = dict['username'], 
                     password      = dict['password'])

file  = open("/tmp/reddit-post-url.txt", "r")   # gaahhh
lines = file.readlines()
title = lines[0].rstrip()
url   = lines[1].rstrip()

subred = reddit.subreddit(dict['subreddit'])
rid = subred.submit(title = title, url = url)

print(rid)

# submission = reddit.submission(id='edmcwf')
# print(submission.title)
# print(submission.url)

