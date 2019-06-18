require "spec"
require "../src/sse"
require "./stub_server"

def start_stub_server
  port = Random.rand(40000..65535)
  spawn do
    address = HTTP::ServerSentEvents.current_stub_server.bind_tcp port
    puts "Listening on http://#{address}"
    HTTP::ServerSentEvents.current_stub_server.listen
  end
  port
end

def stop_stub_server
  HTTP::ServerSentEvents.stop_current_stub_server
end

SPEC_SERVER_PORT = start_stub_server
