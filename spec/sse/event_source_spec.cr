require "../spec_helper"

describe HTTP::ServerSentEvents::EventSource do
  it "Receive 3 events" do
    channel = Channel(Array(String)).new
    event_source = HTTP::ServerSentEvents::EventSource.new("http://localhost:#{SPEC_SERVER_PORT}/events/")
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
  end

  it "Initialize without args" do
    channel = Channel(Array(String)).new
    event_source = HTTP::ServerSentEvents::EventSource.new(URI.parse("http://localhost:#{SPEC_SERVER_PORT}/events/"))
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
  end

  it "Initialize and run without args" do
    channel = Channel(Array(String)).new
    event_source = HTTP::ServerSentEvents::EventSource.new("")
    spawn do
      event_source.on_message do |message|
        channel.send(message.data)
      end
    end
    expect_raises ArgumentError do
      event_source.run
    end
  end

  it "Receive all events" do
    channel = Channel(HTTP::ServerSentEvents::EventMessage).new
    event_source = HTTP::ServerSentEvents::EventSource.new("http://localhost:#{SPEC_SERVER_PORT}/all/")
    spawn do
      event_source.on_message do |message|
        channel.send(message)
      end
      event_source.run
    end
    3.times do
      actual = channel.receive
      actual.retry.should eq 2000
      actual.event.should eq "usermessage"
      actual.data.size.should eq 2
      actual.data[0].should eq "foo"
      actual.data[1].should eq "bar"
    end
    event_source.stop
  end

  it "Invaluid endpoint" do
    channel = Channel(Int32).new
    event_source = HTTP::ServerSentEvents::EventSource.new("http://localhost:#{SPEC_SERVER_PORT}/badrequest/")
    spawn do
      event_source.on_error do |err|
        channel.send(err[:status_code])
      end
      event_source.run
    end
    actual = channel.receive
    actual.should eq 400
  end
end

stop_stub_server
