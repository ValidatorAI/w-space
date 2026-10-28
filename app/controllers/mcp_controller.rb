class McpController < ActionController::API
  MCP_PROTOCOL_VERSION = "2024-11-05"
  SERVER_INFO = {
    name: "bonfire-mcp",
    version: "1.0.0"
  }.freeze

  def handle
    process_jsonrpc(:all)
  end

  def action
    process_jsonrpc(:action)
  end

  def read
    process_jsonrpc(:read)
  end

  def knowledge
    process_jsonrpc(:knowledge)
  end

  def config_endpoint
    process_jsonrpc(:config)
  end

  def task
    process_jsonrpc(:task)
  end

  private

  def process_jsonrpc(scope)
    payload = parse_json_payload
    return if performed?

    req_id = payload["id"]
    method = payload["method"]

    if method.blank?
      render json: jsonrpc_error(-32600, "Invalid Request: missing or invalid 'method'", req_id), status: :ok
      return
    end

    params = payload["params"] || {}
    unless params.is_a?(Hash)
      render json: jsonrpc_error(-32602, "Invalid params: params must be an object", req_id), status: :ok
      return
    end

    case method
    when "initialize"
      render json: jsonrpc_result({
        protocolVersion: MCP_PROTOCOL_VERSION,
        capabilities: { tools: {} },
        serverInfo: SERVER_INFO
      }, req_id)
    when "notifications/initialized", "initialized"
      if req_id.nil?
        head :no_content
      else
        render json: jsonrpc_result({}, req_id)
      end
    when "ping"
      render json: jsonrpc_result({}, req_id)
    when "tools/list"
      render json: jsonrpc_result({
        tools: Mcp::Registry.list_tools(scope)
      }, req_id)
    when "tools/call"
      tool_name = params["name"]
      if tool_name.blank? || !tool_name.is_a?(String)
        render json: jsonrpc_error(-32602, "Invalid params: 'name' is required and must be a string", req_id)
        return
      end

      tool_args = params["arguments"] || {}
      unless tool_args.is_a?(Hash)
        render json: jsonrpc_error(-32602, "Invalid params: 'arguments' must be an object", req_id)
        return
      end

      result = Mcp::Registry.call_tool(tool_name, tool_args, scope: scope, jsonrpc_id: req_id)
      render json: jsonrpc_result(result, req_id)
    else
      render json: jsonrpc_error(-32601, "Method not found: #{method}", req_id)
    end
  rescue StandardError => e
    Rails.logger.error("McpController error: #{e.class.name}: #{e.message}\n#{e.backtrace&.first(10)&.join("\n")}")
    render json: jsonrpc_error(-32603, "Internal error: #{e.message}", req_id)
  end

  def parse_json_payload
    body = request.body.read
    JSON.parse(body)
  rescue JSON::ParserError => e
    render json: jsonrpc_error(-32700, "Parse error: invalid JSON: #{e.message}"), status: :bad_request
    nil
  end

  def jsonrpc_result(result, req_id)
    {
      jsonrpc: "2.0",
      id: req_id,
      result: result
    }
  end

  def jsonrpc_error(code, message, req_id = nil, data = nil)
    err = { code: code, message: message }
    err[:data] = data if data.present?
    {
      jsonrpc: "2.0",
      id: req_id,
      error: err
    }
  end
end
