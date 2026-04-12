import { cleanup, fireEvent, render, screen, waitFor } from '@testing-library/svelte';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';

vi.mock('/routes/index.js', () => ({
  confirm_form_imports_path: vi.fn(() => '/form_imports/confirm'),
  edit_form_path: vi.fn((id: number | string) => `/forms/${id}/edit`),
  form_imports_path: vi.fn(() => '/form_imports'),
  forms_path: vi.fn(() => '/forms'),
}));

import { router } from '@inertiajs/svelte';
import PdfImportModal from '../../../../app/frontend/components/customs/PdfImportModal.svelte';

describe('PdfImportModal.svelte', () => {
  const fetchMock = vi.fn();

  function createPdfFile(size = 128, name = 'import.pdf', type = 'application/pdf'): File {
    return new File([new Uint8Array(size)], name, { type });
  }

  function buildUploadResponse(overrides: Partial<Record<string, unknown>> = {}) {
    return {
      success: true,
      field_count: 2,
      warnings: ['Review generated options.'],
      form_data: {
        name: 'Imported Form',
        structure: {
          description: 'Imported from a PDF.',
          fields: [
            {
              label: 'Company name',
              field_type: 'text',
              required: true,
              position: 1,
              metadata: {},
            },
            {
              label: 'Upload certificate',
              field_type: 'file',
              required: false,
              position: 2,
              metadata: {},
            },
          ],
        },
      },
      ...overrides,
    };
  }

  beforeEach(() => {
    document.head.innerHTML = '<meta name="csrf-token" content="csrf-token" />';
    fetchMock.mockReset();
    vi.stubGlobal('fetch', fetchMock);
    vi.mocked(router.visit).mockClear();
  });

  afterEach(() => {
    cleanup();
    vi.unstubAllGlobals();
  });

  it('renders the drop zone in the idle state', () => {
    render(PdfImportModal, { props: { open: true } });

    expect(screen.getByTestId('pdf-import-idle-state')).toBeInTheDocument();
    expect(screen.getByText(/Drop your PDF here or click to browse/i)).toBeInTheDocument();
  });

  it('shows the uploading state on file selection', async () => {
    let resolveFetch: ((value: Response) => void) | undefined;
    fetchMock.mockImplementationOnce(
      () => new Promise<Response>((resolve) => {
        resolveFetch = resolve;
      }),
    );

    render(PdfImportModal, { props: { open: true } });

    const input = screen.getByTestId('pdf-import-input');
    await fireEvent.change(input, { target: { files: [createPdfFile()] } });

    expect(screen.getByTestId('pdf-import-uploading-state')).toBeInTheDocument();
    expect(screen.getByText('Analyzing your PDF...')).toBeInTheDocument();
    expect(screen.getByRole('status')).toHaveTextContent('Analyzing your PDF. Upload in progress.');

    resolveFetch?.(new Response(JSON.stringify(buildUploadResponse()), { status: 200 }));

    await waitFor(() => {
      expect(screen.getByTestId('pdf-import-preview-state')).toBeInTheDocument();
    });
  });

  it('displays the preview with field count and warnings', async () => {
    fetchMock.mockResolvedValueOnce(new Response(JSON.stringify(buildUploadResponse()), { status: 200 }));

    render(PdfImportModal, { props: { open: true } });

    await fireEvent.change(screen.getByTestId('pdf-import-input'), {
      target: { files: [createPdfFile()] },
    });

    await waitFor(() => {
      expect(screen.getByTestId('pdf-import-preview-state')).toBeInTheDocument();
    });

    expect(screen.getByDisplayValue('Imported Form')).toBeInTheDocument();
    expect(screen.getByText('2')).toBeInTheDocument();
    expect(screen.getByText(/Review generated options/i)).toBeInTheDocument();
    expect(screen.getByText(/Company name/i)).toBeInTheDocument();
    expect(screen.getByTestId('pdf-import-review-reminder')).toHaveTextContent(
      'Your form can contain typos or input errors. Always verify it before showing it to the client.',
    );
  });

  it('resets preview state when closed and reopened', async () => {
    fetchMock.mockResolvedValueOnce(new Response(JSON.stringify(buildUploadResponse()), { status: 200 }));

    const { rerender } = render(PdfImportModal, { props: { open: true } });

    await fireEvent.change(screen.getByTestId('pdf-import-input'), {
      target: { files: [createPdfFile()] },
    });

    await waitFor(() => {
      expect(screen.getByTestId('pdf-import-preview-state')).toBeInTheDocument();
    });

    expect(screen.getByDisplayValue('Imported Form')).toBeInTheDocument();

    await fireEvent.click(screen.getByTestId('pdf-import-close'));
    await rerender({ open: false });
    await rerender({ open: true });

    expect(screen.getByTestId('pdf-import-idle-state')).toBeInTheDocument();
    expect(screen.queryByDisplayValue('Imported Form')).not.toBeInTheDocument();
    expect(screen.queryByText(/Review generated options/i)).not.toBeInTheDocument();
  });

  it('submits the edited preview name on confirm', async () => {
    fetchMock
      .mockResolvedValueOnce(new Response(JSON.stringify(buildUploadResponse()), { status: 200 }))
      .mockResolvedValueOnce(new Response(JSON.stringify({ success: true, form_id: 'form-123' }), { status: 201 }));

    render(PdfImportModal, { props: { open: true } });

    await fireEvent.change(screen.getByTestId('pdf-import-input'), {
      target: { files: [createPdfFile()] },
    });

    await waitFor(() => {
      expect(screen.getByTestId('pdf-import-preview-state')).toBeInTheDocument();
    });

    await fireEvent.input(screen.getByLabelText('Form name'), {
      target: { value: 'Renamed Imported Form' },
    });

    await fireEvent.click(screen.getByRole('button', { name: 'Create form' }));

    await waitFor(() => {
      expect(fetchMock).toHaveBeenCalledTimes(2);
    });

    const confirmRequest = fetchMock.mock.calls[1]?.[1] as RequestInit;
    expect(JSON.parse(String(confirmRequest.body))).toEqual(
      expect.objectContaining({
        form_data: expect.objectContaining({ name: 'Renamed Imported Form' }),
      }),
    );
  });

  it('shows the error state and returns to idle on retry', async () => {
    fetchMock.mockResolvedValueOnce(
      new Response(JSON.stringify({ success: false, error: 'Import failed badly.' }), { status: 422 }),
    );

    render(PdfImportModal, { props: { open: true } });

    await fireEvent.change(screen.getByTestId('pdf-import-input'), {
      target: { files: [createPdfFile()] },
    });

    await waitFor(() => {
      expect(screen.getByTestId('pdf-import-error-state')).toBeInTheDocument();
    });

    expect(screen.getByText(/Import failed badly/i)).toBeInTheDocument();

    await fireEvent.click(screen.getByRole('button', { name: 'Try again' }));

    expect(screen.getByTestId('pdf-import-idle-state')).toBeInTheDocument();
  });

  it('resets error state when closed and reopened', async () => {
    fetchMock.mockResolvedValueOnce(
      new Response(JSON.stringify({ success: false, error: 'Import failed badly.' }), { status: 422 }),
    );

    const { rerender } = render(PdfImportModal, { props: { open: true } });

    await fireEvent.change(screen.getByTestId('pdf-import-input'), {
      target: { files: [createPdfFile()] },
    });

    await waitFor(() => {
      expect(screen.getByTestId('pdf-import-error-state')).toBeInTheDocument();
    });

    await fireEvent.click(screen.getByTestId('pdf-import-close'));
    await rerender({ open: false });
    await rerender({ open: true });

    expect(screen.getByTestId('pdf-import-idle-state')).toBeInTheDocument();
    expect(screen.queryByText(/Import failed badly/i)).not.toBeInTheDocument();
  });

  it('validates file type client-side', async () => {
    render(PdfImportModal, { props: { open: true } });

    const invalidFile = createPdfFile(64, 'notes.txt', 'text/plain');
    await fireEvent.change(screen.getByTestId('pdf-import-input'), {
      target: { files: [invalidFile] },
    });

    expect(screen.getByText(/Only PDF files are accepted/i)).toBeInTheDocument();
    expect(fetchMock).not.toHaveBeenCalled();
  });

  it('validates file size client-side', async () => {
    render(PdfImportModal, { props: { open: true } });

    const largeFile = createPdfFile((10 * 1024 * 1024) + 1);
    await fireEvent.change(screen.getByTestId('pdf-import-input'), {
      target: { files: [largeFile] },
    });

    expect(screen.getByText(/File too large/i)).toBeInTheDocument();
    expect(fetchMock).not.toHaveBeenCalled();
  });

  it('ignores an upload response that finishes after the modal closes', async () => {
    let resolveFetch: ((value: Response) => void) | undefined;
    fetchMock.mockImplementationOnce(
      () => new Promise<Response>((resolve) => {
        resolveFetch = resolve;
      }),
    );

    const { rerender } = render(PdfImportModal, { props: { open: true } });

    await fireEvent.change(screen.getByTestId('pdf-import-input'), {
      target: { files: [createPdfFile()] },
    });

    expect(screen.getByTestId('pdf-import-uploading-state')).toBeInTheDocument();

    await fireEvent.click(screen.getByTestId('pdf-import-close'));
    await rerender({ open: false });

    resolveFetch?.(new Response(JSON.stringify(buildUploadResponse()), { status: 200 }));

    await waitFor(() => {
      expect(screen.queryByTestId('pdf-import-preview-state')).not.toBeInTheDocument();
    });

    await rerender({ open: true });

    expect(screen.getByTestId('pdf-import-idle-state')).toBeInTheDocument();
    expect(screen.queryByDisplayValue('Imported Form')).not.toBeInTheDocument();
  });

  it('ignores a confirm response that finishes after the component unmounts', async () => {
    let resolveConfirm: ((value: Response) => void) | undefined;

    fetchMock
      .mockResolvedValueOnce(new Response(JSON.stringify(buildUploadResponse()), { status: 200 }))
      .mockImplementationOnce(
        () => new Promise<Response>((resolve) => {
          resolveConfirm = resolve;
        }),
      );

    const { unmount } = render(PdfImportModal, { props: { open: true } });

    await fireEvent.change(screen.getByTestId('pdf-import-input'), {
      target: { files: [createPdfFile()] },
    });

    await waitFor(() => {
      expect(screen.getByTestId('pdf-import-preview-state')).toBeInTheDocument();
    });

    await fireEvent.click(screen.getByRole('button', { name: 'Create & Edit' }));
    unmount();

    resolveConfirm?.(new Response(JSON.stringify({ success: true, form_id: 'form-123' }), { status: 201 }));
    await new Promise((resolve) => setTimeout(resolve, 0));

    expect(vi.mocked(router.visit)).not.toHaveBeenCalled();
  });

  it('navigates to the edit page after a successful create and disables confirm actions while pending', async () => {
    let resolveConfirm: ((value: Response) => void) | undefined;

    fetchMock
      .mockResolvedValueOnce(new Response(JSON.stringify(buildUploadResponse()), { status: 200 }))
      .mockImplementationOnce(
        () => new Promise<Response>((resolve) => {
          resolveConfirm = resolve;
        }),
      );

    render(PdfImportModal, { props: { open: true } });

    await fireEvent.change(screen.getByTestId('pdf-import-input'), {
      target: { files: [createPdfFile()] },
    });

    await waitFor(() => {
      expect(screen.getByTestId('pdf-import-preview-state')).toBeInTheDocument();
    });

    await fireEvent.click(screen.getByRole('button', { name: 'Create & Edit' }));

    expect(screen.getByRole('button', { name: 'Creating...' })).toBeDisabled();
    expect(screen.getByRole('button', { name: 'Create form' })).toBeDisabled();
    expect(screen.getByRole('button', { name: 'Close' })).toBeDisabled();
    expect(screen.getByRole('button', { name: 'Try again' })).toBeDisabled();
    expect(screen.getByLabelText('Form name')).toBeDisabled();
    expect(screen.getByRole('button', { name: /Dismiss warning:/i })).toBeDisabled();

    const overlay = document.querySelector('[data-slot="sheet-overlay"]');
    expect(overlay).not.toBeNull();
    if (!overlay) throw new Error('Expected sheet overlay to exist');

    await fireEvent.pointerDown(overlay);
    await fireEvent.click(overlay);
    await fireEvent.keyDown(screen.getByRole('dialog'), { key: 'Escape' });

    expect(screen.getByTestId('pdf-import-preview-state')).toBeInTheDocument();

    resolveConfirm?.(new Response(JSON.stringify({ success: true, form_id: 'form-123' }), { status: 201 }));

    await waitFor(() => {
      expect(vi.mocked(router.visit)).toHaveBeenCalledWith('/forms/form-123/edit');
    });
  });

  it('navigates to the forms index after a successful create form action', async () => {
    fetchMock
      .mockResolvedValueOnce(new Response(JSON.stringify(buildUploadResponse()), { status: 200 }))
      .mockResolvedValueOnce(new Response(JSON.stringify({ success: true, form_id: 'form-123' }), { status: 201 }));

    render(PdfImportModal, { props: { open: true } });

    await fireEvent.change(screen.getByTestId('pdf-import-input'), {
      target: { files: [createPdfFile()] },
    });

    await waitFor(() => {
      expect(screen.getByTestId('pdf-import-preview-state')).toBeInTheDocument();
    });

    await fireEvent.click(screen.getByRole('button', { name: 'Create form' }));

    await waitFor(() => {
      expect(vi.mocked(router.visit)).toHaveBeenCalledWith('/forms');
    });
  });

  it('shows confirm errors without leaving the preview state', async () => {
    fetchMock
      .mockResolvedValueOnce(new Response(JSON.stringify(buildUploadResponse()), { status: 200 }))
      .mockResolvedValueOnce(
        new Response(
          JSON.stringify({ success: false, error: 'Invalid form data', details: ['Missing field label'] }),
          { status: 422 },
        ),
      );

    render(PdfImportModal, { props: { open: true } });

    await fireEvent.change(screen.getByTestId('pdf-import-input'), {
      target: { files: [createPdfFile()] },
    });

    await waitFor(() => {
      expect(screen.getByTestId('pdf-import-preview-state')).toBeInTheDocument();
    });

    await fireEvent.click(screen.getByRole('button', { name: 'Create form' }));

    await waitFor(() => {
      expect(screen.getByText(/Invalid form data Missing field label/i)).toBeInTheDocument();
    });

    expect(screen.getByTestId('pdf-import-preview-state')).toBeInTheDocument();
    expect(vi.mocked(router.visit)).not.toHaveBeenCalled();
  });
});