module Swagger
  module Docs
    class SwaggerDSL
      # http://stackoverflow.com/questions/5851127/change-the-context-binding-inside-a-block-in-ruby/5851325#5851325
      def self.call(action, caller, &block)
        # Create a new SwaggerDSL instance, and instance_eval the block to it
        instance = new
        instance.instance_eval(&block)
        # Now return all of the set instance variables as a Hash
        instance.instance_variables.inject({}) { |result_hash, instance_variable|
          result_hash[instance_variable] = instance.instance_variable_get(instance_variable)
          result_hash # Gotta have the block return the result_hash
        }
      end

      def summary(text)
        @summary = text
      end
      
      def notes(text)
        @notes = text
      end

      def method(method)
        @method = method
      end

      def type(type)
        @type = type
      end

      def nickname(nickname)
        @nickname = nickname
      end

      def parameters
        @parameters ||= []
      end

      def param(param_type, name, type, required, description = nil, hash={})
        parameters << {:param_type => param_type, :name => name, :type => type,
          :description => description, :required => required == :required}.merge(hash)
      end

      # helper method to generate complex object
      def param_object(klass, params={})
        klass_ancestors = eval(klass).ancestors.map(&:to_s)
        if klass_ancestors.include?('ActiveRecord::Base')
          param_active_record(klass, params)
        elsif klass_ancestors.include?('Virtus::Model::Core')
          param_virtus(klass, params)
        end
      end

      # helper method to generate ActiveRecord::Base object
      def param_active_record(klass, params={})
        remove_attributes = [:id, :created_at, :updated_at]
        remove_attributes += params[:remove] if params[:remove]

        test = eval(klass).new
        test.valid?
        eval(klass).columns.each do |column|
          unless remove_attributes.include?(column.name.to_sym)
            param column.name.to_sym,
                  column.name.to_sym,
                  column.type.to_sym,
                  (test.errors.messages[column.name.to_sym] ? :required : :optional),
                  column.name.split('_').map(&:capitalize).join(' ')
          end
        end
      end

      # helper method to generate Virtus object
      def param_virtus(klass, params={})
        remove_attributes = []
        remove_attributes += params[:remove] if params[:remove]

        eval(klass).new.attributes.keys.each do |key|
          unless remove_attributes.include?(key)
            param key,
                  key,
                  :unrecognized,
                  :optional,
                  key.to_s.split('_').map(&:capitalize).join(' ')
          end
        end
      end
  
      # helper method to generate enums
      def param_list(param_type, name, type, required, description = nil, allowed_values = [], hash = {})
        hash.merge!({allowable_values: {value_type: "LIST", values: allowed_values}})
        param(param_type, name, type, required, description, hash)
      end

      def response_messages
        @response_messages ||= []
      end

      def response(status, text = nil, model = nil)
        if status.is_a? Symbol
          status_code = Rack::Utils.status_code(status)
          response_messages << {:code => status_code, :message => text || status.to_s.titleize}
        else
          response_messages << {:code => status, :message => text}
        end
        response_messages.sort_by!{|i| i[:code]}
      end
    end

    class SwaggerModelDSL
      attr_accessor :id

      # http://stackoverflow.com/questions/5851127/change-the-context-binding-inside-a-block-in-ruby/5851325#5851325
      def self.call(model_name, caller, &block)
        # Create a new SwaggerModelDSL instance, and instance_eval the block to it
        instance = new
        instance.instance_eval(&block)
        instance.id = model_name
        # Now return all of the set instance variables as a Hash
        instance.instance_variables.inject({}) { |result_hash, instance_var_name|
          key = instance_var_name[1..-1].to_sym  # Strip prefixed @ sign.
          result_hash[key] = instance.instance_variable_get(instance_var_name)
          result_hash # Gotta have the block return the result_hash
        }
      end

      def properties
        @properties ||= {}
      end

      def required
        @required ||= []
      end

      def description(description)
        @description = description
      end

      def property(name, type, required, description = nil, hash={})
        properties[name] = {
          type: type,
          description: description,
        }.merge!(hash)
        self.required << name if required == :required
      end
    end
  end
end
