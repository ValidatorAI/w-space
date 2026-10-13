module Mcp
  class Registry
    include Singleton

    attr_reader :tools_by_name, :tools_by_alias, :scoped_tools

    def initialize
      reset!
    end

    def reset!
      @tools_by_name = {}
      @tools_by_alias = {}
      @scoped_tools = {
        action: Set.new,
        read: Set.new,
        knowledge: Set.new,
        task: Set.new,
        all: Set.new
      }
    end

    def register(tool_instance, scopes: [:all])
      name = tool_instance.name.to_s
      @tools_by_name[name] = tool_instance
      @scoped_tools[:all].add(name)

      Array(scopes).each do |s|
        @scoped_tools[s.to_sym]&.add(name)
      end

      tool_instance.aliases.each do |a|
        @tools_by_alias[a.to_s] = tool_instance
        @scoped_tools[:all].add(a.to_s)
        Array(scopes).each do |s|
          @scoped_tools[s.to_sym]&.add(a.to_s)
        end
      end
    end

    def find_tool(name, scope: :all)
      tool_name = name.to_s
      return nil unless scope == :all || @scoped_tools[scope.to_sym]&.include?(tool_name)

      @tools_by_name[tool_name] || @tools_by_alias[tool_name]
    end

    def list_tools(scope = :all)
      target_names = scope == :all ? @tools_by_name.keys : (@tools_by_name.keys & @scoped_tools[scope.to_sym].to_a)
      target_names.sort.map do |tname|
        tool = @tools_by_name[tname]
        {
          name: tool.name,
          description: tool.description,
          inputSchema: tool.input_schema
        }
      end
    end

    def call_tool(name, args = {}, scope: :all, jsonrpc_id: nil)
      tool = find_tool(name, scope: scope)
      unless tool
        return {
          content: [{ type: "text", text: "Tool '#{name}' not found in scope '#{scope}'" }],
          isError: true
        }
      end

      Mcp::CallLogger.wrap(tool_name: name, jsonrpc_id: jsonrpc_id, params: args) do
        tool.call(args)
      end
    end

    def self.register(tool_instance, scopes: [:all])
      instance.register(tool_instance, scopes: scopes)
    end

    def self.find_tool(name, scope: :all)
      instance.find_tool(name, scope: scope)
    end

    def self.list_tools(scope = :all)
      instance.list_tools(scope)
    end

    def self.call_tool(name, args = {}, scope: :all, jsonrpc_id: nil)
      instance.call_tool(name, args, scope: scope, jsonrpc_id: jsonrpc_id)
    end

    def self.reset!
      instance.reset!
    end
  end
end
