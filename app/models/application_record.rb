module ActiveModel
  module SchematizedJson
    extend ActiveSupport::Concern

    module ClassMethods
      def has_json(attr, **schema)
        define_method(attr) do
          _write_attribute(attr.to_s, {}) if attribute(attr.to_s).nil?
          ActiveModel::SchematizedJson::DataAccessor.new(schema, data: attribute(attr.to_s))
        end

        define_method("#{attr}=") { |data| public_send(attr).assign_data_with_type_casting(data) }
        before_save -> { send(attr) } if respond_to?(:before_save)
      end

      def has_delegated_json(attr, **schema)
        has_json attr, **schema

        schema.keys.each do |schema_key|
          define_method(schema_key) { public_send(attr).public_send(schema_key) }
          define_method("#{schema_key}?") { public_send(attr).public_send("#{schema_key}?") }
          define_method("#{schema_key}=") { |value| send(attr).public_send("#{schema_key}=", value) }
        end
      end
    end

    class DataAccessor
      def initialize(schema, data:)
        @schema = schema
        @data = data
        update_data_with_schema_defaults
      end

      def assign_data_with_type_casting(new_data)
        new_data.each { |key, value| public_send("#{key}=", value) }
      end

      private

        def method_missing(method_name, *args, **kwargs)
          key = method_name.to_s.sub(/(\?|=)\z/, "")

          if @schema.key?(key.to_sym)
            if method_name.to_s.end_with?("?")
              @data[key].present?
            elsif method_name.to_s.end_with?("=")
              @data[key] = lookup_schema_type_for(key).cast(args.first)
            else
              @data[key]
            end
          else
            super
          end
        end

        def respond_to_missing?(method_name, include_private = false)
          @schema.key?(method_name.to_s.sub(/[?=]\z/, "").to_sym) || super
        end

        def lookup_schema_type_for(key)
          type_or_default_value = @schema[key.to_sym]

          case type_or_default_value
          when :boolean, :integer, :string
            ActiveModel::Type.lookup(type_or_default_value)
          when TrueClass, FalseClass
            ActiveModel::Type.lookup(:boolean)
          when Integer
            ActiveModel::Type.lookup(:integer)
          when String
            ActiveModel::Type.lookup(:string)
          else
            raise ArgumentError, "Only boolean, integer, or strings are allowed as JSON schema types"
          end
        end

        def update_data_with_schema_defaults
          @data.reverse_merge!(@schema.to_h { |attr, type| [attr.to_s, type.is_a?(Symbol) ? nil : type] })
        end
    end
  end
end

class ApplicationRecord < ActiveRecord::Base
  include ActiveModel::SchematizedJson
  primary_abstract_class
end
