class FileRetentionPolicy

  STARTS_ON = "first_download".freeze

  def self.purge_delay_seconds
    ENV.fetch("UPLOADED_FILE_PURGE_DELAY_SECONDS", 1.day.to_i).to_i
  end

  def self.purge_delay
    purge_delay_seconds.seconds
  end

  def self.as_json(*_args)
    {
      starts_on: STARTS_ON,
      purge_delay_seconds: purge_delay_seconds
    }
  end

end