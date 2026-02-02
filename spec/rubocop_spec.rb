require 'open3'

RSpec.describe 'RuboCop' do
  it 'has no style offenses' do
    # Run rubocop via bundle exec to ensure project config is used
    cmd = 'bundle exec rubocop'
    stdout, stderr, status = Open3.capture3(cmd)
    unless status.success?
      warn stdout
      warn stderr
    end

    expect(status.success?).to be true
  end
end
