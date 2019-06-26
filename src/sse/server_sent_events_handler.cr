require "http"
require "./event_message"

class HTTP::ServerSentEventsHandler
  include HTTP::Handler

  struct EventStream
    getter last_event_id

    def initialize(@io : IO, @last_event_id : String? = nil)
    end

    def source(&@event_source : -> HTTP::ServerSentEvents::EventMessage?) : EventStream
      self
    end

    private def sink(message : HTTP::ServerSentEvents::EventMessage)
      message.id.try do |id|
        @io.print("id: #{id}\n")
      end
      message.retry.try do |retry|
        @io.print("retry: #{retry}\n")
      end
      message.event.try do |event|
        @io.print("event: #{event}\n")
      end
      message.data.each do |data|
        @io.print("data: #{data}\n")
      end
      @io.print("\n")
      @io.flush
    end

    def run
      loop do
        @event_source.try do |e|
          e.call.try do |m|
            sink m
          end
        end
      end
    end
  end

  def initialize(&@proc : EventStream, Server::Context -> EventStream)
  end

  def call(context)
    if acceptable_request? context.request
      response = context.response
      response.content_type = "text/event-stream"
      response.headers["Cache-Control"] = "no-cache"
      response.headers["Connection"] = "keep-alive"
      response.upgrade do |io|
        stream = EventStream.new io, context.request.headers["Last-Event-ID"]?
        @proc.call(stream, context).run
        io.close
      end
    else
      call_next context
    end
  end

  private def acceptable_request?(request)
    request.headers["Accept"]?.try &.== "text/event-stream"
  end
end
