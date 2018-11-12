require "spec"
require "../src/sse"

describe HTTP::ServerSentEvents do
  it "Receive 3 events" do
    channel = Channel(Array(String)).new
    event_source = HTTP::ServerSentEvents::EventSource.new("http://localhost:8080/events/")
    spawn do
      event_source.on_message do |message|
        channel.send(message.datas)
      end
      event_source.run
    end
    3.times do
      actual = channel.receive
      actual.size.should eq 2
      (actual[1].to_i - actual[0].to_i).should eq 1
    end
    event_source.abort
  end

  it "Initialize without args" do
    channel = Channel(Array(String)).new
    event_source = HTTP::ServerSentEvents::EventSource.new
    spawn do
      event_source.on_message do |message|
        channel.send(message.datas)
      end
      event_source.run(URI.parse("http://localhost:8080/events/"))
    end
    3.times do
      actual = channel.receive
      actual.size.should eq 2
      (actual[1].to_i - actual[0].to_i).should eq 1
    end
    event_source.abort
  end

  it "Initialize and run without args" do
    channel = Channel(Array(String)).new
    event_source = HTTP::ServerSentEvents::EventSource.new
    spawn do
      event_source.on_message do |message|
        channel.send(message.datas)
      end
    end
    expect_raises URI::Error do
      event_source.run
    end
  end

  it "Receive all events" do
    channel = Channel(HTTP::ServerSentEvents::EventSource::EventMessage).new
    event_source = HTTP::ServerSentEvents::EventSource.new("http://localhost:8080/all/")
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
      actual.datas.size.should eq 2
      actual.datas[0].should eq "foo"
      actual.datas[1].should eq "bar"
    end
    event_source.abort
  end

  it "Invaluid endpoint" do
    channel = Channel(Int32).new
    event_source = HTTP::ServerSentEvents::EventSource.new("http://localhost:8080/badrequest/")
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
