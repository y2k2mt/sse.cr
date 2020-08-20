require "../spec_helper"

describe HTTP::ServerSentEvents::Handler do
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
      HTTP::ServerSentEvents::Handler.new { |es, _|
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

  it "Receive multiple events" do
    server = HTTP::Server.new [
      HTTP::ServerSentEvents::Handler.new { |es, _|
        es.source("57f") {
          sleep 1
          HTTP::ServerSentEvents::EventMessage.new(
            id: "43e",
            data: ["foo", "bar"],
            retry: 2000,
          )
        }.source("67g") {
          sleep 1.1
          HTTP::ServerSentEvents::EventMessage.new(
            id: "43g",
            data: ["baz", "qux"],
            retry: 1000,
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

    actuals = [] of HTTP::ServerSentEvents::EventMessage
    6.times do
      actuals << channel.receive
    end
    actuals.each_with_index do |actual, i|
      case i
      when 0
        actual.event.should eq "57f"
        actual.retry.should eq 2000
        actual.data.size.should eq 2
        actual.data[0].should eq "foo"
        actual.data[1].should eq "bar"
      when 1
        actual.event.should eq "67g"
        actual.retry.should eq 1000
        actual.data.size.should eq 2
        actual.data[0].should eq "baz"
        actual.data[1].should eq "qux"
      when 2
        actual.event.should eq "57f"
      when 3
        actual.event.should eq "67g"
      when 4
        actual.event.should eq "57f"
      when 5
        actual.event.should eq "67g"
      end
      event_source.stop
    end
  end
end
