import { router } from '@inertiajs/svelte';
import { client_form_invitation_delivery_path } from '@/routes';

export interface SendOptions {
  onFinish?: () => void;
}

/**
 * POSTs to the invitation_delivery endpoint requesting immediate delivery.
 * Accepts an optional `onFinish` callback for resetting loading state in the caller.
 */
export function sendInvitation(
  clientFormId: string | number,
  options?: SendOptions,
): void {
  router.post(
    client_form_invitation_delivery_path(clientFormId),
    { send_now: 'true' },
    {
      preserveScroll: true,
      onFinish: options?.onFinish,
    },
  );
}

/**
 * POSTs to the invitation_delivery endpoint skipping immediate delivery.
 */
export function skipInvitation(clientFormId: string | number): void {
  router.post(
    client_form_invitation_delivery_path(clientFormId),
    { send_now: 'false' },
    { preserveScroll: true },
  );
}
