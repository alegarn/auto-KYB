<script lang="ts">
  import { router } from '@inertiajs/svelte';
  import { settings_auth_setup_path } from '@/routes';

  let { user, google_auth_url } = $props<{
    user: { email: string };
    google_auth_url: string;
  }>();
  const csrfToken =
    typeof document === 'undefined'
      ? ''
      : ((document.querySelector('meta[name="csrf-token"]') as HTMLMetaElement)?.content || '');

  function chooseEmail() {
    router.patch(settings_auth_setup_path(), {});
  }
</script>

<div class="min-h-screen flex items-center justify-center bg-gray-50 px-4">
  <div class="max-w-md w-full bg-white rounded-xl shadow-md p-8 space-y-6">
    <div class="text-center">
      <h1 class="text-2xl font-bold text-gray-900">Welcome to Quick KYB</h1>
      <p class="mt-2 text-sm text-gray-500">
        You're signed in as <span class="font-medium text-gray-700">{user.email}</span>.
        How would you like to sign in next time?
      </p>
    </div>

    <div class="space-y-3">
      <!-- Google OAuth option -->
      <form action={google_auth_url} method="post" data-turbo="false">
        <input type="hidden" name="authenticity_token" value={csrfToken} />
        <button
          type="submit"
          class="flex items-center justify-center gap-3 w-full border border-gray-300 text-gray-700 py-3 px-4 rounded-lg hover:bg-gray-50 transition font-medium"
        >
          <svg class="w-5 h-5" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">
            <path d="M22.56 12.25c0-.78-.07-1.53-.2-2.25H12v4.26h5.92c-.26 1.37-1.04 2.53-2.21 3.31v2.77h3.57c2.08-1.92 3.28-4.74 3.28-8.09z" fill="#4285F4"/>
            <path d="M12 23c2.97 0 5.46-.98 7.28-2.66l-3.57-2.77c-.98.66-2.23 1.06-3.71 1.06-2.86 0-5.29-1.93-6.16-4.53H2.18v2.84C3.99 20.53 7.7 23 12 23z" fill="#34A853"/>
            <path d="M5.84 14.1c-.22-.66-.35-1.36-.35-2.1s.13-1.44.35-2.1V7.07H2.18C1.43 8.55 1 10.22 1 12s.43 3.45 1.18 4.93l2.85-2.22.81-.61z" fill="#FBBC05"/>
            <path d="M12 5.38c1.62 0 3.06.56 4.21 1.64l3.15-3.15C17.45 2.09 14.97 1 12 1 7.7 1 3.99 3.47 2.18 7.07l3.66 2.84c.87-2.6 3.3-4.53 6.16-4.53z" fill="#EA4335"/>
          </svg>
          Do you want to use Google auth for future login?
        </button>
      </form>

      <!-- Email link option -->
      <button
        type="button"
        onclick={chooseEmail}
        class="flex items-center justify-center gap-3 w-full bg-indigo-600 text-white py-3 px-4 rounded-lg hover:bg-indigo-700 transition font-medium"
      >
        <svg class="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 8l7.89 5.26a2 2 0 002.22 0L21 8M5 19h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z"/>
        </svg>
        Continue with Email Links
      </button>
    </div>

    <p class="text-xs text-center text-gray-400">
      You can always change this later in your account settings.
    </p>
  </div>
</div>
