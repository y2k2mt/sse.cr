require "http/server"

module HTTP::ServerSentEvents
  def self.current_stub_server
    if @@current
      return @@current.not_nil!
    end
    @@current = HTTP::Server.new do |context|
      case context.request.path
      when "/events/"
        context.response.content_type = "text/event-stream"
        context.response.headers["Cache-Control"] = "no-cache"
        context.response.headers["Connection"] = "keep-alive"
        context.response.status_code = 200
        context.response.print '\n'
        counter = 1
        loop do
          context.response.print("data: #{counter += 1}\n")
          context.response.print("data: #{counter += 1}\n\n")
          context.response.flush
          sleep Time::Span.new(seconds: 2)
        end
      when "/all/"
        context.response.content_type = "text/event-stream"
        context.response.headers["Cache-Control"] = "no-cache"
        context.response.headers["Connection"] = "keep-alive"
        context.response.status_code = 200
        context.response.print '\n'
        id = 1
        loop do
          context.response.print("id: #{id += 1}\n")
          context.response.print("retry: 2000\n")
          context.response.print("event: usermessage\n")
          context.response.print("data: foo\n")
          context.response.print("data: bar\n\n")
          context.response.flush
          sleep Time::Span.new(seconds: 2)
        end
      when "/invalid-format/"
        loop do
          context.response.print("data\n")
          context.response.print("\n")
          context.response.print("data:\n\n")
          context.response.flush
          sleep Time::Span.new(seconds: 2)
        end
      when "/multiline-format/"
        loop do
          context.response.print("data\n")
          context.response.print("data\n\n")
          context.response.flush
          sleep Time::Span.new(seconds: 2)
        end
      when "/badrequest/"
        context.response.status_code = 400
      else
        context.response.status_code = 404
      end
    end
    @@current.not_nil!
  end

  def self.stop_current_stub_server
    if @@current
      begin
        @@current.not_nil!.close
      ensure
        @@current = nil
      end
    end
  end
end
