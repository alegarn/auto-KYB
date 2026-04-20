import { describe, it, expect, vi } from 'vitest';

vi.mock('@inertiajs/svelte', () => ({
  router: { post: vi.fn() },
}));

vi.mock('@/routes', () => ({
  client_form_invitation_delivery_path: vi.fn((id) => `/clients/${id}/invitation_delivery`),
}));

import { router } from '@inertiajs/svelte';
import { client_form_invitation_delivery_path } from '@/routes';
import { sendInvitation, skipInvitation } from '@/lib/invitation-delivery';

describe('sendInvitation', () => {
  it('calls router.post with the correct path and send_now: true', () => {
    const postSpy = vi.mocked(router.post);
    postSpy.mockClear();

    sendInvitation(42);

    expect(client_form_invitation_delivery_path).toHaveBeenCalledWith(42);
    expect(postSpy).toHaveBeenCalledOnce();
    expect(postSpy).toHaveBeenCalledWith(
      '/clients/42/invitation_delivery',
      { send_now: 'true' },
      expect.objectContaining({ preserveScroll: true }),
    );
  });

  it('passes onFinish through to router.post options', () => {
    const postSpy = vi.mocked(router.post);
    postSpy.mockClear();

    const onFinish = vi.fn();
    sendInvitation('7', { onFinish });

    expect(postSpy).toHaveBeenCalledWith(
      expect.any(String),
      { send_now: 'true' },
      expect.objectContaining({ onFinish }),
    );
  });

  it('does not pass send_now: false', () => {
    const postSpy = vi.mocked(router.post);
    postSpy.mockClear();

    sendInvitation(1);

    const [, body] = postSpy.mock.calls[0];
    expect(body).not.toEqual(expect.objectContaining({ send_now: 'false' }));
  });
});

describe('skipInvitation', () => {
  it('calls router.post with the correct path and send_now: false', () => {
    const postSpy = vi.mocked(router.post);
    postSpy.mockClear();

    skipInvitation(99);

    expect(client_form_invitation_delivery_path).toHaveBeenCalledWith(99);
    expect(postSpy).toHaveBeenCalledOnce();
    expect(postSpy).toHaveBeenCalledWith(
      '/clients/99/invitation_delivery',
      { send_now: 'false' },
      expect.objectContaining({ preserveScroll: true }),
    );
  });

  it('does not pass an onFinish callback', () => {
    const postSpy = vi.mocked(router.post);
    postSpy.mockClear();

    skipInvitation(99);

    const [, , options] = postSpy.mock.calls[0];
    expect(options).not.toHaveProperty('onFinish');
  });
});

describe('path building', () => {
  it('sendInvitation builds the path using client_form_invitation_delivery_path', () => {
    vi.mocked(client_form_invitation_delivery_path).mockClear();

    sendInvitation(123);

    expect(client_form_invitation_delivery_path).toHaveBeenCalledWith(123);
  });

  it('skipInvitation builds the path using client_form_invitation_delivery_path', () => {
    vi.mocked(client_form_invitation_delivery_path).mockClear();

    skipInvitation(456);

    expect(client_form_invitation_delivery_path).toHaveBeenCalledWith(456);
  });
});
