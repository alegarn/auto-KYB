require 'rails_helper'

RSpec.describe 'Database schema for form_responses' do
  let(:conn) { ActiveRecord::Base.connection }

  it 'has form_responses table with expected columns and types' do
    expect(conn.table_exists?(:form_responses)).to be true
    columns = conn.columns(:form_responses).map(&:name)
    expect(columns).to include('id', 'client_form_id', 'data', 'version', 'created_at', 'updated_at')

    id_col = conn.columns(:form_responses).find { |c| c.name == 'id' }
    expect(id_col).not_to be_nil
    expect(id_col.sql_type).to include('uuid')

    data_col = conn.columns(:form_responses).find { |c| c.name == 'data' }
    expect(data_col).not_to be_nil
    expect(data_col.sql_type).to include('jsonb')
  end
end
