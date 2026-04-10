Summary
=======

This documents the small UX improvement added to the pricing buttons.

- File changed: app/frontend/components/customs/pricing.svelte
- Behavior: clicking a plan button (`basic` or `pro`) sets a per-plan loading state, shows a spinner inside the clicked button, and disables that button until the network request finishes or navigation occurs.

Implementation notes
--------------------
- Uses a local `loadingPlan` state inside `pricing.svelte`.
- Uses `Loader2` from `@lucide/svelte/icons/loader-2` for the spinner SVG.
- The existing `Button` component accepts `disabled` and preserves slot content, so no change to `Button` was required.

Rails / Inertia considerations
-----------------------------
- The existing `fetch` POST to `/checkout_sessions` is left intact (Rails controller handles it). If the server returns `data.url` the page navigates to that URL. On network error we fall back to `router.visit(sign_up_path())`.
- The spinner state is cleared when the request completes with no redirect or on error prior to navigation.

Tests
-----
- A unit test was added to assert the spinner appears and the button gets disabled while a subscribe request is in progress.

If you want I can now run the test suite locally and fix any failures.
