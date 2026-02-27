class CrmConnection < ApplicationRecord
  belongs_to :user
  has_many :crm_transfers, dependent: :destroy
end
