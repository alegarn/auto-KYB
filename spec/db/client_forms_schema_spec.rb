require 'rails_helper'

RSpec.describe 'Database schema for client_forms' do
  let(:conn) { ActiveRecord::Base.connection }

  it 'has client_forms table with expected columns and types' do
    expect(conn.table_exists?(:client_forms)).to be true
    columns = conn.columns(:client_forms).map(&:name)
    expect(columns).to include('id', 'client_id', 'form_id', 'status', 'password_digest', 'access_token', 'expires_at', 'validated_at', 'created_at', 'updated_at')

    id_col = conn.columns(:client_forms).find { |c| c.name == 'id' }
    expect(id_col).not_to be_nil
    expect(id_col.sql_type).to include('uuid')

    data_col = conn.columns(:client_forms).find { |c| c.name == 'status' }
    expect(data_col).not_to be_nil
    expect(data_col.sql_type).to include('integer')
  end
end
