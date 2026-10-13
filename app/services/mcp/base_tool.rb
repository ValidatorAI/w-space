module Mcp
  class BaseTool
    def name
      raise NotImplementedError, "#{self.class} must implement #name"
    end

    def description
      raise NotImplementedError, "#{self.class} must implement #description"
    end

    def input_schema
      {
        type: "object",
        properties: {},
        required: []
      }
    end

    def aliases
      []
    end

    # Subclasses override execute(args) and return a Hash, String, or call success/failure
    def execute(args)
      raise NotImplementedError, "#{self.class} must implement #execute"
    end

    def call(args = {})
      args = (args || {}).with_indifferent_access
      execute(args)
    rescue ActiveRecord::RecordNotFound => e
      failure("Record not found: #{e.message}")
    rescue ActiveRecord::RecordInvalid => e
      failure("Validation failed: #{e.record.errors.full_messages.join(', ')}")
    rescue StandardError => e
      failure("#{e.class.name}: #{e.message}")
    end

    protected

    def success(result_data)
      formatted_text = format_result(result_data)
      {
        content: [
          {
            type: "text",
            text: formatted_text
          }
        ],
        isError: false
      }
    end

    def failure(error_message)
      {
        content: [
          {
            type: "text",
            text: error_message.to_s
          }
        ],
        isError: true
      }
    end

    def format_result(result)
      return "Success" if result.nil?
      return result if result.is_a?(String)

      JSON.pretty_generate(result.as_json)
    rescue StandardError
      result.to_s
    end

    def boolean_param(val)
      return nil if val.nil?
      return val if val.is_a?(TrueClass) || val.is_a?(FalseClass)
      val.to_s.downcase.in?(%w[true 1 yes on])
    end
  end
end
