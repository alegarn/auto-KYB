module Crm
  class ClientCreateSyncExecutor
    def initialize(client:, connection:, service:, request_context:)
      @client = client
      @connection = connection
      @service = service
      @context = request_context.to_h
      @sync_address = ActiveRecord::Type::Boolean.new.cast(@context['sync_address_to_contact'])
    end

    def call
      contact_id = resolve_contact_id
      company_id = resolve_company_id
      associate_contact_to_company(contact_id, company_id) if contact_id.present? && company_id.present?

      { external_contact_id: contact_id, external_company_id: company_id }
    end

    private

    def link
      @link ||= CrmClientLink.find_or_initialize_by(client: @client, crm_connection: @connection)
    end

    def persist_contact_id!(id)
      return if id.blank?

      link.external_contact_id = id
      link.save!
    end

    def persist_company_id!(id)
      return if id.blank?

      link.external_company_id = id
      link.save!
    end

    # --- Contact resolution (idempotent) ---

    def resolve_contact_id
      # 1. Reuse previously stored id
      existing = link.external_contact_id.presence
      return existing if existing

      # 2. Search by email if provider supports it
      if @client.email.present? && @service.respond_to?(:search_contact_by_email)
        found = @service.search_contact_by_email(@client.email)
        if found && found[:id].present?
          persist_contact_id!(found[:id])
          return found[:id]
        end
      end

      # 3. Create as last resort
      result = @service.create_contact(@client, sync_address_to_contact: @sync_address)
      contact_id = result && result[:id].presence
      persist_contact_id!(contact_id)
      contact_id
    end

    # --- Company resolution (idempotent) ---

    def resolve_company_id
      # 1. Prefer explicit id from request context
      explicit_id = @context['external_company_id'].presence
      if explicit_id
        persist_company_id!(explicit_id)
        return explicit_id
      end

      # 2. Reuse previously stored id
      existing = link.external_company_id.presence
      return existing if existing

      # 3. Search / create only if company name is present
      return nil if @client.company_name.blank?

      company_id = search_company_by_name
      if company_id.blank?
        company_id = create_company
      end

      persist_company_id!(company_id)
      company_id
    end

    def search_company_by_name
      found = @service.search_companies(@client.company_name) || []
      return nil unless found.any?

      exact = found.find { |c| c[:company_name].to_s.casecmp?(@client.company_name) }
      exact[:hubspot_id] || exact[:id] if exact
    rescue NoMethodError
      nil
    end

    def create_company
      created = @service.create_company(@client, {})
      created[:id] if created
    rescue NoMethodError
      nil
    end

    # --- Association ---

    def associate_contact_to_company(contact_id, company_id)
      @service.associate_contact_to_company(contact_id, company_id)
    rescue NoMethodError
      # provider doesn't support association; ignore
    end
  end
end
