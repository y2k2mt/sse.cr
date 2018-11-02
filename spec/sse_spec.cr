require "spec"
require "../src/sse"

describe HTTP::ServerSentEvents do
  event_source = HTTP::ServerSentEvents::EventSource.new("http://localhost:8080/events/")

  it "Receive 3 events" do
    channel = Channel(Array(String)).new
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
  end
end
