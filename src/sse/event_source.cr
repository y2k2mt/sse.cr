require "uri"
require "http/client"
require "./event_message"
require "./log"

module HTTP::ServerSentEvents
  class EventSource
    class_property default_retry_duration : Int64 = 3000

    protected getter last_id : String? = nil
    protected getter? abort : Bool = false

    def initialize(uri : String, base_headers : HTTP::Headers? = nil)
      initialize URI.parse(uri), base_headers
    end

    def initialize(@uri : URI, @base_headers : HTTP::Headers? = nil)
    end

    def on_message(&@on_message : EventMessage ->) : Nil
    end

    def on_error(&@on_error : NamedTuple(status_code: Int32, message: String) ->) : Nil
    end

    def stop : Nil
      LOG.info { "[#{@uri}] Stop to listening event source" }
      @abort = true
    end

    def run : Nil
      LOG.info { "[#{@uri}] Start to listening event source" }
      loop do
        break if abort?

        LOG.info { "[#{@uri}] Preparing to send request to the endpoint : #{prepare_headers}" }
        HTTP::Client.get(@uri, headers: prepare_headers) do |response|
          case response.status
          when .ok?
            successful_response response
          when .found?, .see_other?, .temporary_redirect?
            temporary_redirect response
          when .service_unavailable?
            service_unavailable response
          else
            @on_error.try &.call({
              status_code: response.status_code,
              message:     response.body_io?.try(&.gets_to_end) || "",
            })
            stop
          end
        end
      end
    end

    private def successful_response(response)
      lines = [] of String
      io = response.body_io
      last_message = nil
      LOG.debug { "[#{@uri}] Response from the endpoint has been successfully received." }

      loop do
        break if @abort
        break unless line = io.gets

        if line.empty? && !lines.empty?
          last_message = parse_event_message(lines)
          last_message.id.try { |id| @last_id = id }
          @on_message.try &.call(last_message)
          lines.clear
        else
          lines << line
        end
      end

      unless last_message.try(&.id.try(&.empty?)) && @abort
        last_message.try(&.retry.try do |retry_after_seconds|
          sleep (retry_after_seconds).seconds
        end)
      end
    end

    private def temporary_redirect(response)
      location = response.headers["Location"]
      LOG.warn { "[#{@uri}] A response from the endpoint indicates another endpoint [#{location}]" }
      @uri = URI.parse(location)
    end

    private def service_unavailable(response)
      @on_error.try &.call({
        status_code: response.status_code,
        message:     response.body_io?.try(&.gets_to_end) || "",
      })
      LOG.warn { "[#{@uri}] The endpoint temporary unavailable due to #{response.body_io?.try(&.gets_to_end)}" }
      response.headers["Retry-After"]?.try { |retry_after|
        retry_after.to_i64?.try { |delay_seconds|
          sleep (delay_seconds).seconds
        } || http_date?(retry_after)
      } || stop
    end

    private def http_date?(retry_after : String)
      delay_seconds = (Time::Format::HTTP_DATE.parse(retry_after) - Time.utc).total_seconds
      if delay_seconds > 0
        sleep (delay_seconds.to_i64).seconds
      end
    rescue e : Time::Format::Error
      LOG.warn { "[#{@uri}] The endpoint responses invalid format Retry-After header [#{retry_after}]" }
      nil
    end

    private def prepare_headers : HTTP::Headers
      headers = HTTP::Headers{
        "Accept"        => "text/event-stream",
        "Cache-Control" => "no-cache",
      }
      if last_id = @last_id
        headers["Last-Event-ID"] = last_id
      end
      if base_headers = @base_headers
        headers.merge! base_headers
      end
      headers
    end

    private def parse_event_message(lines : Array(String)) : EventMessage
      id, event, retry = nil, nil, nil
      data = [] of String

      lines.each_with_index do |line, i|
        field_delimiter = line.index(':')
        if field_delimiter
          field_name = line[0...field_delimiter]
          field_value = line[field_delimiter + 2..line.size - 1]?
        elsif !line.empty?
          field_name = line
          field_value = lines[i + 1]?
        end

        if field_name && field_value
          case field_name
          when "id"
            id = field_value
          when "data"
            data << field_value
          when "retry"
            retry = field_value.to_i64?
          when "event"
            event = field_value
          else
            # Ignore
          end
        end
      end

      EventMessage.new(
        id: id,
        data: data,
        retry: retry || @@default_retry_duration,
        event: event
      )
    end
  end
end
