Crystal shard for server-sent-events
===

[![Build Status](https://travis-ci.org/y2k2mt/sse.cr.svg?branch=master)](https://travis-ci.org/y2k2mt/sse.cr)

[Server-Sent-Events](https://www.w3.org/TR/2009/WD-eventsource-20090421/) library for crystal.

Now on supports only client.

Usage 
---

```crystal
sse = HTTP::ServerSentEvents::EventSource.new("http://app/ssedemo")

sse.on_message do |message|
  # Recieving messages from server
  p message.datas
end

sse.run
```

How to test
---

```shell
# Running node sse server
npm install
npm start &

# Run specs
crystal spec
```
