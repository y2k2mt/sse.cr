# server-sent-events

[![Build Status](https://travis-ci.org/y2k2mt/sse.cr.svg?branch=master)](https://travis-ci.org/y2k2mt/sse.cr)
[![Releases](https://img.shields.io/github/release/y2k2mt/sse.cr.svg?maxAge=360)](https://github.com/y2k2mt/sse.cr/releases)
 
[Server-Sent-Events](https://www.w3.org/TR/2009/WD-eventsource-20090421/) library for crystal.

Now supports only client.

## Installation

1. Add the dependency to your `shard.yml`:

```yaml
dependencies:
  sse:
    github: y2k2mt/sse.cr
    version: 0.3.0
```

2. Run `shards install`

## Usage


```crystal
sse = HTTP::ServerSentEvents::EventSource.new("http://app/ssedemo")

sse.on_message do |message|
  # Recieving messages from server
  p message.data
end

sse.run
```

## How to test
---

```shell
# Running node sse server
npm install
npm start &

# Run specs
crystal spec
```

## Contributing

1. Fork it (<https://github.com/y2k2mt/sse.cr/fork>)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## Contributors

- [y2k2mt](https://github.com/y2k2mt) - creator and maintainer
