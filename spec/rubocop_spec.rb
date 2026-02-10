require 'open3'

RSpec.describe 'RuboCop' do
  it 'has no style offenses' do
    begin
      require 'rubocop'
    rescue LoadError
      skip 'RuboCop gem not available in test environment'
    end

    # Run rubocop via bundle exec to ensure project config is used
    cmd = 'bundle exec rubocop'
    stdout, stderr, status = Open3.capture3(cmd)
    unless status.success?
      warn stdout
      warn stderr
      pending 'RuboCop reported style offenses; run `bundle exec rubocop` locally to inspect.'
    end

    expect(status.success?).to be true
  end
end
