require 'minitest/autorun'

class QuickstartValidationTest < Minitest::Test
  def test_quickstart_exists_and_has_sample_requests
    path = File.join(__dir__, '..', 'specs', '002-form-management', 'quickstart.md')
    refute_nil path
    assert File.exist?(path), "Expected quickstart.md to exist at #{path}"

    content = File.read(path)
    assert_includes content, 'POST /forms', 'quickstart.md should include a sample POST /forms request'
    assert_includes content, 'GET /forms', 'quickstart.md should include a sample GET /forms request'
  end
end
