require "uri"
require "http/client"

module HTTP::ServerSentEvents

  class EventSource

    record EventMessage, event : String, datas : Array(String), id : String, retry : Int64

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

    def run(uri : URI = @uri, last_id : (String | Nil) = nil)
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
            retry = 0.to_i64
            an_entry = [] of String
            io = response.try &.body_io
            loop do
              if @abort
                break
              end
              line = io.gets
              if line
                if line.empty? && an_entry.size != 0
                  entry_hash = parse_to_hash(an_entry)
                  last_id = entry_hash["id"].as(String)
                  retry? = entry_hash["retry"].as(String).to_i64?
                  if retry?
                    retry = retry?
                  end
                  @on_message.try &.call(EventMessage.new(
                    id: last_id,
                    datas: entry_hash["datas"].as(Array(String)),
                    retry: retry,
                    event: entry_hash["event"].as(String)
                  ))
                  an_entry = [] of String
                else
                  an_entry = an_entry << line
                end
              else
                break
              end
            end
            if (last_id && !last_id.empty?) && !@abort
              sleep retry / 1000
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
              @aboart = true
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

    private def parse_to_hash(entry : Array(String)) : Hash(String, (String | Array(String)))
      event_source = {"id" => "", "datas" => [] of String, "retry" => "1000", "event" => ""}
      entry.each { |line|
        i = line.index(':')
        if i
          field_name = line[0...i]
          field_value = line[i + 2..line.size - 1]
          case field_name
          when "data"
            event_source["datas"].as(Array(String)) << field_value
          else
            event_source[field_name] = field_value
          end
        end
      }
      event_source
    end

  end

end
