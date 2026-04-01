require 'rails_helper'

RSpec.describe CrmConnection, type: :model do
  describe 'associations' do
    it 'belongs to a user' do
      user = create(:user)
      conn = create(:crm_connection, user: user)
      expect(conn.user).to eq(user)
    end

    it 'has many crm_transfers' do
      conn = create(:crm_connection)
      transfer = create(:crm_transfer, crm_connection: conn)
      expect(conn.crm_transfers).to include(transfer)
    end
  end

  describe 'validations' do
    it 'validates presence of provider' do
      conn = build(:crm_connection, provider: nil)
      expect(conn).not_to be_valid
      expect(conn.errors[:provider]).to include("can't be blank")
    end

    it 'validates inclusion of provider' do
      conn = build(:crm_connection, provider: 'invalid')
      expect(conn).not_to be_valid
      expect(conn.errors[:provider]).to include("is not included in the list")
    end

    it 'validates uniqueness of provider scoped to user' do
      user = create(:user)
      create(:crm_connection, user: user, provider: 'hubspot')
      conn2 = build(:crm_connection, user: user, provider: 'hubspot')
      expect(conn2).not_to be_valid
      expect(conn2.errors[:provider]).to include("connection already exists")
    end

    it 'validates presence of status' do
      conn = build(:crm_connection, status: nil)
      expect(conn).not_to be_valid
      expect(conn.errors[:status]).to include("can't be blank")
    end
  end

  describe 'scopes' do
    it 'filters active connections' do
      active = create(:crm_connection, status: 'active')
      inactive = create(:crm_connection, status: 'disconnected')

      expect(CrmConnection.active).to include(active)
      expect(CrmConnection.active).not_to include(inactive)
    end
  end

  describe '#active?' do
    it 'returns true if status is active' do
      expect(build(:crm_connection, status: 'active')).to be_active
    end

    it 'returns false otherwise' do
      expect(build(:crm_connection, status: 'disconnected')).not_to be_active
    end
  end

  describe '#token_expired?' do
    it 'returns true if expires_at is in the past' do
      expect(build(:crm_connection, expires_at: 1.second.ago)).to be_token_expired
    end

    it 'returns false if expires_at is in the future' do
      expect(build(:crm_connection, expires_at: 1.hour.from_now)).not_to be_token_expired
    end

    it 'returns false if expires_at is nil' do
      expect(build(:crm_connection, expires_at: nil)).not_to be_token_expired
    end
  end

  describe '#token_expires_soon?' do
    it 'returns true if expires_at is within the buffer' do
      expect(build(:crm_connection, expires_at: 4.minutes.from_now)).to be_token_expires_soon
    end

    it 'returns false if expires_at is beyond the buffer' do
      expect(build(:crm_connection, expires_at: 1.hour.from_now)).not_to be_token_expires_soon
    end

    it 'can accept a custom buffer' do
      expect(build(:crm_connection, expires_at: 10.minutes.from_now)).to be_token_expires_soon(buffer: 15.minutes)
    end
  end
end
