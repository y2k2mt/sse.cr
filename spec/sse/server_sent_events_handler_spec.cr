require "../spec_helper"

describe HTTP::ServerSentEventsHandler do
  it "Receive 3 events" do
    counter = 0
    server = HTTP::Server.new [
      HTTP::ServerSentEventsHandler.new { |es, _|
        es.source {
          sleep 1
          HTTP::ServerSentEvents::EventMessage.new(
            data: ["#{counter += 1}", "#{counter += 1}"],
          )
        }
      },
    ]
    port = Random.rand(40000..65535)
    spawn do
      server.bind_tcp "127.0.0.1", port
      server.listen
    end
    channel = Channel(Array(String)).new
    event_source = HTTP::ServerSentEvents::EventSource.new("http://localhost:#{port}/events/")
    spawn do
      event_source.on_message do |message|
        channel.send(message.data)
      end
      event_source.run
    end
    3.times do
      actual = channel.receive
      actual.size.should eq 2
      (actual[1].to_i - actual[0].to_i).should eq 1
    end
    event_source.stop
    server.close
  end

  it "Receive all events" do
    server = HTTP::Server.new [
      HTTP::ServerSentEventsHandler.new { |es, _|
        es.source {
          sleep 1
          HTTP::ServerSentEvents::EventMessage.new(
            event: "usermessage",
            id: "43e",
            data: ["foo", "bar"],
            retry: 2000,
          )
        }
      },
    ]
    port = Random.rand(40000..65535)
    spawn do
      server.bind_tcp "127.0.0.1", port
      server.listen
    end
    channel = Channel(HTTP::ServerSentEvents::EventMessage).new
    event_source = HTTP::ServerSentEvents::EventSource.new("http://localhost:#{port}/all/")
    spawn do
      event_source.on_message do |message|
        channel.send(message)
      end
      event_source.run
    end
    3.times do
      actual = channel.receive
      actual.id.should eq "43e"
      actual.retry.should eq 2000
      actual.event.should eq "usermessage"
      actual.data.size.should eq 2
      actual.data[0].should eq "foo"
      actual.data[1].should eq "bar"
    end
    event_source.stop
    server.close
  end
end
