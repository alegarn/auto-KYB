class CrmClientLink < ApplicationRecord

  belongs_to :client
  belongs_to :crm_connection

end
