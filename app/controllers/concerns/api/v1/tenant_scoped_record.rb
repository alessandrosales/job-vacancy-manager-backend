# frozen_string_literal: true

module Api
  module V1
    # Carrega um registro apenas dentro do escopo +current_user.<associação>+ e responde 404 se
    # o ID não pertencer ao tenant (mesmo padrão descrito em docs/security-multi-tenant-api.md).
    #
    #   include TenantScopedRecord
    #   tenant_scoped_record :opportunity, :opportunities, only: %i[show update destroy]
    #
    module TenantScopedRecord
      extend ActiveSupport::Concern

      class_methods do
        def tenant_scoped_record(instance_name, association, param_key: :id, only: nil, except: nil)
          setter = :"set_#{instance_name}"
          ivar = :"@#{instance_name}"

          define_method setter do
            scope = current_user.public_send(association)
            record = scope.find_by(id: params[param_key])
            head(:not_found) && return if record.blank?

            instance_variable_set(ivar, record)
          end

          before_action setter, only: only, except: except
        end
      end
    end
  end
end
