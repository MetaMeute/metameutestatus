#!/usr/bin/env python2.7
import feedparser
import time
import sys
import urllib
import urllib2
import getpass

BASE = "https://status.metameute.de/"

if len(sys.argv) > 1:
  msg = " ".join(sys.argv[1:])

  values = {'source' : getpass.getuser(),
            'message' : msg,
            'submit' : "submit" }

  data = urllib.urlencode(values)
  req = urllib2.Request(BASE, data)
  req.get_method = lambda: "POST"
  response = urllib2.urlopen(req)
  code = response.getcode()
  if code == 200:
    print "Message posted!"
  else:
    print "An error occured. Return code", code
    sys.exit(1)

feed = feedparser.parse( BASE + "rss" )
for item in reversed(feed["items"]):
  print time.strftime("%d %b %Y %H:%M:%S", item["published_parsed"]), item["title"]
