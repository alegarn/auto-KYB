class CrmTransfer < ApplicationRecord
  belongs_to :client
  belongs_to :crm_connection
end
