require 'rails_helper'

RSpec.describe 'Database schema for forms and form_fields' do
  let(:conn) { ActiveRecord::Base.connection }

  it 'has forms table with expected columns and types' do
    expect(conn.table_exists?(:forms)).to be true
    columns = conn.columns(:forms).map(&:name)
    expect(columns).to include('id', 'user_id', 'name', 'structure', 'created_at', 'updated_at')

    structure_col = conn.columns(:forms).find { |c| c.name == 'structure' }
    expect(structure_col).not_to be_nil
    expect(structure_col.sql_type).to include('jsonb')

    id_col = conn.columns(:forms).find { |c| c.name == 'id' }
    expect(id_col).not_to be_nil
    expect(id_col.sql_type).to include('uuid')
  end

  it 'has form_fields table with expected columns and types' do
    expect(conn.table_exists?(:form_fields)).to be true
    columns = conn.columns(:form_fields).map(&:name)
    expect(columns).to include('id', 'form_id', 'label', 'field_type', 'required', 'position', 'metadata', 'created_at', 'updated_at')

    metadata_col = conn.columns(:form_fields).find { |c| c.name == 'metadata' }
    expect(metadata_col).not_to be_nil
    expect(metadata_col.sql_type).to include('jsonb')

    required_col = conn.columns(:form_fields).find { |c| c.name == 'required' }
    expect(required_col).not_to be_nil
    expect(required_col.sql_type).to include('boolean')
  end
end
