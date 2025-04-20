# Server-Sent Events

[![Build Status](https://github.com/y2k2mt/sse.cr/actions/workflows/crystal.yml/badge.svg)](https://github.com/y2k2mt/sse.cr/actions/workflows/crystal.yml)
[![Releases](https://img.shields.io/github/release/y2k2mt/sse.cr.svg?maxAge=360)](https://github.com/y2k2mt/sse.cr/releases)

[Server-Sent Events](https://www.w3.org/TR/eventsource/) server/client for Crystal.

## Installation

1. Add the dependency to your `shard.yml`:

```yaml
dependencies:
  sse:
    github: y2k2mt/sse.cr
```

2. Run `shards install`

## Usage

### Client

```crystal
require "sse"

sse = HTTP::ServerSentEvents::EventSource.new("http://127.0.0.1:8080")

sse.on_message do |message|
  # Receiving messages from server
  p message.data
end

sse.run
```

### Server

```crystal
require "sse"

server = HTTP::Server.new [
  HTTP::ServerSentEvents::Handler.new { |es, _|
    es.source {
      # Delivering event data every 1 second.
      sleep 1
      HTTP::ServerSentEvents::EventMessage.new(
        data: ["foo", "bar"],
      )
    }
  },
]

server.bind_tcp "127.0.0.1", 8080
server.listen
```

Running server and you can get then:

```
$ curl 127.0.0.1:8080 -H "Accept: text/event-stream"

data: foo
data: bar

data: foo
data: bar

...

```

## Contributing

1. Fork it (<https://github.com/y2k2mt/sse.cr/fork>)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## Contributors

- [y2k2mt](https://github.com/y2k2mt) - creator and maintainer
