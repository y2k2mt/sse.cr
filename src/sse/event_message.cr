require "uri"

module HTTP::ServerSentEvents
  record EventMessage, data : Array(String), event : String? = nil, id : String? = nil, retry : Int64? = nil
end
