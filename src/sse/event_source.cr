require "uri"
require "http/client"

module HTTP::ServerSentEvents
  record EventMessage, event : String?, data : Array(String), id : String?, retry : Int64

  class EventSource
    @@default_retry_duration : Int64 = 3000.to_i64

    @last_id : String? = nil
    @abort : Bool = false

    def initialize(uri : String, headers : HTTP::Headers = HTTP::Headers.new)
      initialize(URI.parse(uri), headers)
    end

    def initialize(@uri : URI, @base_headers : HTTP::Headers = HTTP::Headers.new)
    end

    def on_message(&@on_message : EventMessage ->)
    end

    def on_error(&@on_error : NamedTuple(status_code: Int32, message: String) ->)
    end

    def on_close(&@on_close : String ->)
    end

    def stop
      @abort = true
    end

    def run
      loop do
        if @abort
          break
        end
        HTTP::Client.get(@uri, headers: prepare_headers) do |response|
          case response.status_code
          when 200
            successful_response response
          when 302 | 303 | 307
            tempolary_redirection response
          when 503
            service_unavairable response
          else
            body = response.body_io?
            if body
              @on_error.try &.call({status_code: response.status_code, message: body.gets_to_end})
            else
              @on_error.try &.call({status_code: response.status_code, message: ""})
            end
            stop
          end
        end
      end
    end

    private def successful_response(response)
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
    end

    private def tempolary_redirection(response)
      location = response.headers["Location"]
      @uri = URI.parse(location)
    end

    private def service_unavairable(response)
      body = response.body_io?
      if body
        @on_error.try &.call({status_code: response.status_code, message: body.gets_to_end})
      else
        @on_error.try &.call({status_code: response.status_code, message: ""})
      end
      # Ignore date formatted header
      response.headers["Retry-After"]?.try &.to_i64?.try { |retry_after|
        sleep retry_after / 1000
      } || {stop}
    end

    private def prepare_headers
      headers = HTTP::Headers.new
      if @last_id
        headers.add("Last-Event-Id", "#{@last_id}")
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
