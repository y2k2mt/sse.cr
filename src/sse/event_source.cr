require "uri"
require "http/client"

module HTTP::ServerSentEvents
  record EventMessage, event : String?, data : Array(String), id : String?, retry : Int64

  class EventSource
    @@default_retry_duration : Int64 = 3000.to_i64

    def initialize(host : String, path : String, port : Int32, tls = false, headers : HTTP::Headers = HTTP::Headers.new)
      scheme = tls ? "https" : "http"
      initialize(URI.new(scheme: scheme, host: host, path: path, port: port), headers)
    end

    def initialize(uri : String, headers : HTTP::Headers = HTTP::Headers.new)
      initialize(URI.parse(uri), headers)
    end

    def initialize(@uri : URI | Nil = nil, @base_headers : HTTP::Headers = HTTP::Headers.new)
      @abort = false
    end

    def on_message(&@on_message : EventMessage ->)
    end

    def on_error(&@on_error : NamedTuple(status_code: Int32, message: String) ->)
    end

    def on_close(&@on_close : String ->)
    end

    def abort
      @abort = true
    end

    def run(uri : URI = @uri, last_id : String? = nil)
      if !uri
        raise URI::Error.new("Endpoint URI must be specified")
      end
      loop do
        if @abort
          break
        end
        HTTP::Client.get(uri, headers: prepare_headers(last_id)) do |response|
          case response.status_code
          when 200
            an_entry = [] of String
            io = response.try &.body_io
            last_message = nil
            loop do
              if @abort
                break
              end
              line = io.gets
              if !line
                break
              end
              if line.empty? && an_entry.size != 0
                last_message = parse_event_message(an_entry)
                an_entry = [] of String
                @on_message.try &.call(last_message.not_nil!)
              else
                an_entry = an_entry << line
              end
            end
            if !last_message.not_nil!.id.try &.empty? && !@abort
              sleep last_message.not_nil!.retry / 1000
            end
          when 307
            location = response.headers["Location"]
            uri = URI.parse(location)
          when 503
            body = response.body_io?
            if body
              @on_error.try &.call({status_code: response.status_code, message: body.gets_to_end})
            else
              @on_error.try &.call({status_code: response.status_code, message: ""})
            end
            # Ignore date formatted header
            retry_after = response.headers["Retry-After"].to_i64?
            if retry_after
              sleep retry_after / 1000
            else
              @abort = true
            end
          else
            body = response.body_io?
            if body
              @on_error.try &.call({status_code: response.status_code, message: body.gets_to_end})
            else
              @on_error.try &.call({status_code: response.status_code, message: ""})
            end
            @abort = true
          end
        end
      end
    end

    private def prepare_headers(last_id : String | Nil)
      headers = HTTP::Headers.new
      if last_id
        headers.add("Last-Event-Id", "#{last_id}")
      end
      headers.add("Accept", "text/event-stream")
      headers.add("Cache-Control", "no-cache")
      headers.merge! @base_headers
    end

    private def parse_event_message(entry : Array(String)) : EventMessage
      id, event, retry = nil, nil, nil
      event_datas = [] of String
      entry.each { |line|
        field_delimiter = line.index(':')
        if field_delimiter
          field_name = line[0...field_delimiter]
          field_value = line[field_delimiter + 2..line.size - 1]
          case field_name
          when "id"
            id = field_value
          when "data"
            event_datas << field_value
          when "retry"
            retry = field_value
          when "event"
            event = field_value
          else
            raise "Undefined field '#{field_name}'"
          end
        end
      }
      EventMessage.new(
        id: id,
        data: event_datas,
        retry: retry.try &.to_i64? || @@default_retry_duration,
        event: event,
      )
    end
  end
end
