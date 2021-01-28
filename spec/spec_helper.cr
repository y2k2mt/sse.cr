require "spec"
require "../src/sse"
require "./stub_server"
require "log"

def start_stub_server
  port = Random.rand(40000..65535)
  spawn do
    HTTP::ServerSentEvents.current_stub_server.bind_tcp port
    HTTP::ServerSentEvents.current_stub_server.listen
  end
  port
end

def stop_stub_server
  HTTP::ServerSentEvents.stop_current_stub_server
end

SPEC_SERVER_PORT = start_stub_server
