module Grape
  module Validations
    class BetweenValidator < Base
      def validate_param!(attr_name, params)
        passed_param = params[attr_name]
        return unless params.is_a?(Hash)
        return unless passed_param || required_for_root_scope?

        from = @option.first.is_a?(Proc) ? @option.first.call : @option.first
        to = @option.last.is_a?(Proc) ? @option.last.call : @option.last

        if !passed_param.nil? && ( param_type(passed_param) == from.class  )    # too strict, cf.: (5.4).between?(4,7)
          param_array = Array.wrap(params[attr_name])
          return if param_array.all? { |param| param.between?(from,to) }
        end
        fail Grape::Exceptions::Validation, params: [@scope.full_name(attr_name)], message_key: :values
      end


      private

      def required_for_root_scope?
        @required && @scope.root?
      end

      def param_type param
        param.respond_to?(:first) ? param.first.class : param.class
      end
    end
  end
end
