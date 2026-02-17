class UploadedFileSerializer

  def initialize(uploaded_file)
    @uploaded_file = uploaded_file
  end

  def as_json(*)
    return nil unless @uploaded_file

    {
      "id" => @uploaded_file.id,
      "field_key" => @uploaded_file.field_key,
      "filename" => @uploaded_file.filename,
      "content_type" => @uploaded_file.content_type,
      "byte_size" => @uploaded_file.byte_size,
      "uploaded_at" => @uploaded_file.uploaded_at&.iso8601,
      "downloaded_at" => @uploaded_file.downloaded_at&.iso8601,
      "purge_scheduled_at" => @uploaded_file.purge_scheduled_at&.iso8601,
      "status" => @uploaded_file.status
    }
  end

  def self.collection(relation)
    relation.map { |uf| new(uf).as_json }
  end

  def self.by_field_key(relation)
    relation.each_with_object({}) do |uf, hash|
      hash[uf.field_key] = new(uf).as_json
    end
  end

end
