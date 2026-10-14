module Mcp
  module Tools
    class HelloTool < Mcp::BaseTool
      def name
        "hello"
      end

      def description
        "Say hello to a given name or the world"
      end

      def input_schema
        {
          type: "object",
          properties: {
            name: {
              type: "string",
              description: "The name to greet",
              default: "World"
            }
          }
        }
      end

      def execute(args)
        greeting_name = args[:name].presence || "World"
        success("Hello, #{greeting_name}!")
      end
    end
  end
end
