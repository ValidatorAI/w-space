module Mcp
  class CallLogger
    SENSITIVE_KEYS = %w[password token secret authorization bearer key bearer_token api_key].freeze

    def self.wrap(tool_name:, jsonrpc_id: nil, params: {})
      start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      sanitized_params = sanitize(params)

      result = yield

      duration_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time) * 1000).round
      is_error = result.is_a?(Hash) && result[:isError] == true

      preview_text = if result.is_a?(Hash) && result[:content].is_a?(Array)
                       result[:content].map { |c| c[:text] || c["text"] }.join("\n")
                     else
                       result.to_s
                     end

      McpCallLog.create(
        jsonrpc_id: jsonrpc_id.to_s,
        tool_call_name: tool_name.to_s,
        params_sanitized: sanitized_params,
        is_error: is_error,
        error_message: is_error ? preview_text.truncate(1000) : nil,
        result_preview: preview_text.truncate(2000),
        result_size: preview_text.bytesize,
        duration_ms: duration_ms
      )

      result
    rescue StandardError => e
      duration_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time) * 1000).round rescue 0

      McpCallLog.create(
        jsonrpc_id: jsonrpc_id.to_s,
        tool_call_name: tool_name.to_s,
        params_sanitized: sanitized_params,
        is_error: true,
        error_message: "#{e.class.name}: #{e.message}".truncate(1000),
        duration_ms: duration_ms
      ) rescue nil

      McpException.create(
        tool_call_name: tool_name.to_s,
        exception_class: e.class.name,
        error_message: e.message.to_s,
        backtrace: e.backtrace&.first(20)&.join("\n"),
        params_sanitized: sanitized_params
      ) rescue nil

      raise e
    end

    def self.sanitize(data)
      case data
      when Hash
        data.each_with_object({}) do |(k, v), acc|
          acc[k] = if SENSITIVE_KEYS.any? { |sk| k.to_s.downcase.include?(sk) }
                     "[FILTERED]"
                   else
                     sanitize(v)
                   end
        end
      when Array
        data.map { |item| sanitize(item) }
      else
        data
      end
    end
  end
end
