require "http"
require "./event_message"

module HTTP::ServerSentEvents
  class Handler
    include HTTP::Handler

    struct EventStream
      getter last_event_id : String?

      DEFAULT_EVENT_SOURCE_KEY = "_default"

      def initialize(@io : IO, @last_event_id = nil)
        @event_sources = {} of String => -> EventMessage?
      end

      def source(key : String = DEFAULT_EVENT_SOURCE_KEY, &event_source : -> EventMessage?) : EventStream
        @event_sources[key] = event_source
        self
      end

      private def sink(message : EventMessage)
        message.id.try do |id|
          @io.puts "id: #{id}"
        end
        message.retry.try do |retry|
          @io.puts "retry: #{retry}"
        end
        message.event.try do |event|
          @io.puts "event: #{event}"
        end
        message.data.each do |data|
          @io.puts "data: #{data}"
        end
        @io.puts
        begin
          @io.flush
        rescue e : IO::Error
          LOG.debug { e.inspect }
        end
      end

      def run
        mutex = Mutex.new
        @event_sources.each do |event_name, event_source|
          spawn do
            loop do
              event_source.try &.call.try do |message|
                if event_name != DEFAULT_EVENT_SOURCE_KEY
                  message = message.copy_with(event: event_name)
                end
                mutex.synchronize do
                  sink message
                end
              end
            end
          end
        end
        sleep
      end
    end

    def initialize(&@proc : EventStream, Server::Context -> EventStream)
    end

    def call(context)
      request = context.request
      if acceptable_request? request
        response = context.response
        response.content_type = "text/event-stream"
        response.headers["Cache-Control"] = "no-cache"
        response.headers["Connection"] = "keep-alive"
        response.upgrade do |io|
          stream = EventStream.new(io, request.headers["Last-Event-ID"]?)
          @proc.call(stream, context).run
          io.close
        end
      else
        call_next context
      end
    end

    private def acceptable_request?(request)
      request.headers["Accept"]? == "text/event-stream"
    end
  end
end

@[Deprecated("Use HTTP::ServerSentEvents::Handler instead")]
alias HTTP::ServerSentEventsHandler = HTTP::ServerSentEvents::Handler
