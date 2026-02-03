require 'rails_helper'

RSpec.describe 'Migration: create_forms_and_form_fields' do
  let(:conn) { ActiveRecord::Base.connection }

  it 'creates forms table with expected columns and types' do
    expect(conn.table_exists?(:forms)).to be true
    cols = conn.columns(:forms).map(&:name)
    expect(cols).to include('id', 'user_id', 'name', 'structure', 'created_at', 'updated_at')

    structure = conn.columns(:forms).find { |c| c.name == 'structure' }
    expect(structure).not_to be_nil
    expect(structure.sql_type).to include('jsonb')

    id = conn.columns(:forms).find { |c| c.name == 'id' }
    expect(id.sql_type).to include('uuid')
  end

  it 'creates form_fields table with expected columns and types' do
    expect(conn.table_exists?(:form_fields)).to be true
    cols = conn.columns(:form_fields).map(&:name)
    expect(cols).to include('id', 'form_id', 'label', 'field_type', 'required', 'position', 'metadata', 'created_at', 'updated_at')

    metadata = conn.columns(:form_fields).find { |c| c.name == 'metadata' }
    expect(metadata).not_to be_nil
    expect(metadata.sql_type).to include('jsonb')

    required = conn.columns(:form_fields).find { |c| c.name == 'required' }
    expect(required).not_to be_nil
    expect(required.sql_type).to include('boolean')
  end
end
