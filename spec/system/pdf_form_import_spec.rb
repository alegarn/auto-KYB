require 'rails_helper'

RSpec.describe 'PDF form import', type: :system, js: true do
  before do
    driven_by(:selenium_chrome_headless)
  end

  let(:preview_data) do
    {
      'name' => 'Imported KYB Form',
      'structure' => {
        'description' => 'Imported from a PDF preview.',
        'fields' => [
          {
            'label' => 'Company name',
            'field_type' => 'text',
            'required' => true,
            'position' => 1,
            'metadata' => {}
          },
          {
            'label' => 'Upload certificate',
            'field_type' => 'file',
            'required' => false,
            'position' => 2,
            'metadata' => {}
          }
        ],
        'settings' => {
          'primary_color' => '#2563eb',
          'form_background_color' => '#ffffff',
          'header_background_color' => '#f8fafc'
        }
      }
    }
  end

  let(:service_result) do
    PdfFormImportService::Result.new(
      success: true,
      data: preview_data,
      warnings: [ 'Review file uploads before publishing.' ],
      errors: []
    )
  end

  before do
    allow(PdfFormImportService).to receive(:call).and_return(service_result)
  end

  def with_temp_file(filename:, content:)
    Tempfile.create([ File.basename(filename, '.*'), File.extname(filename) ]) do |file|
      file.binmode
      file.write(content)
      file.rewind
      yield file.path
    end
  end

  def minimal_pdf_content
    "%PDF-1.4\n1 0 obj\n<< /Type /Catalog >>\nendobj\ntrailer\n<< /Root 1 0 R >>\n%%EOF\n"
  end

  def invalid_text_content
    'not a pdf'
  end

  it 'uploads a PDF, shows a preview, and creates the form then lands in the form builder' do
    sign_in_user
    visit forms_path

    click_button 'Import from PDF'

    with_temp_file(filename: 'import.pdf', content: minimal_pdf_content) do |path|
      attach_file('pdf-import-input', path, make_visible: true)
    end

    expect(page).to have_field('pdf-import-form-name', with: 'Imported KYB Form')
    expect(page).to have_content('Review file uploads before publishing.')

    click_button 'Create & Edit'

    expect(page).to have_current_path(%r{/forms/[^/]+/edit}, wait: 10)
    expect(page).to have_content('Edit Form')
  end

  it 'uploads a PDF, shows a preview, and creates the form then lands on the forms index' do
    user = sign_in_user
    visit forms_path

    click_button 'Import from PDF'

    with_temp_file(filename: 'import.pdf', content: minimal_pdf_content) do |path|
      attach_file('pdf-import-input', path, make_visible: true)
    end

    expect(page).to have_field('pdf-import-form-name', with: 'Imported KYB Form')

    click_button 'Create form'

    expect(page).to have_current_path(forms_path, wait: 10)
    expect(user.forms.reload.exists?(name: 'Imported KYB Form')).to be(true)
  end

  it 'shows an error when the user uploads an invalid file' do
    sign_in_user
    visit forms_path

    click_button 'Import from PDF'

    with_temp_file(filename: 'notes.txt', content: invalid_text_content) do |path|
      attach_file('pdf-import-input', path, make_visible: true)
    end

    expect(page).to have_content('Only PDF files are accepted.')
  end

  it 'allows retrying after an error' do
    sign_in_user
    visit forms_path

    click_button 'Import from PDF'

    with_temp_file(filename: 'notes.txt', content: invalid_text_content) do |path|
      attach_file('pdf-import-input', path, make_visible: true)
    end

    expect(page).to have_content('Only PDF files are accepted.')

    click_button 'Try again'
    expect(page).to have_content('Drop your PDF here or click to browse')

    with_temp_file(filename: 'import.pdf', content: minimal_pdf_content) do |path|
      attach_file('pdf-import-input', path, make_visible: true)
    end

    expect(page).to have_field('pdf-import-form-name', with: 'Imported KYB Form')
  end

  it 'resets the modal state after close and reopen' do
    sign_in_user
    visit forms_path

    click_button 'Import from PDF'

    with_temp_file(filename: 'import.pdf', content: minimal_pdf_content) do |path|
      attach_file('pdf-import-input', path, make_visible: true)
    end

    expect(page).to have_field('pdf-import-form-name', with: 'Imported KYB Form')

    find('[data-testid="pdf-import-close"]').click
    expect(page).to have_no_field('pdf-import-form-name')
    expect(page).to have_no_css('[data-testid="pdf-import-close"]')
    expect(page).to have_no_css('[data-slot="sheet-overlay"]')
    expect(page).to have_no_css('[data-slot="sheet-content"]')

    page.execute_script("Array.from(document.querySelectorAll('button')).find((button) => button.textContent.includes('Import from PDF'))?.click()")
    expect(page).to have_content('Drop your PDF here or click to browse')
    expect(page).to have_no_content('Review file uploads before publishing.')
  end
end
