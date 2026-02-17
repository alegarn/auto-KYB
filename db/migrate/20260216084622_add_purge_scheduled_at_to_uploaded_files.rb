class AddPurgeScheduledAtToUploadedFiles < ActiveRecord::Migration[8.1]
  def change
    add_column :uploaded_files, :purge_scheduled_at, :datetime
    add_index :uploaded_files, :purge_scheduled_at
  end
end
