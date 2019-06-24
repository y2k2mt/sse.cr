require "http"

class HTTP::ServerSentEventsHandler
  include HTTP::Handler

  struct EventStream
    def initialize(@io : IO,@last_event_id : String? = nil)
    end

    def push(message : HTTP::ServerSentEvents::EventMessage)
    end
  end

  def initialize(&@proc : EventStream, Server::Context ->)
  end

  def call(context)
    if acceptable_request? context.request
      response = context.response
      response.content_type = "text/event-stream"
      response.headers["Cache-Control"] = "no-cache"
      response.headers["Connection"] = "keep-alive"
      response.upgrade do |io|
	stream = EventStream.new io,request.headers["Last-Event-Id"]?
        stream.run
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
