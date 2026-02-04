<script lang="ts">
  import { client_portal_form_response_path } from '@/routes';
  // Svelte 5 rune-first implementation
  const { client, form, last_response }: { client: any; form: any; last_response?: any } = $props();

  let data = $state<Record<string, any>>({});
  let statusMessage = $state('');

  $effect(() => {
    if (last_response && last_response.data) {
      data = { ...last_response.data };
    }
  });

  async function save(validate = false): Promise<void> {
    statusMessage = 'Saving...';

    const payload = { form_response: { data, validate } };

    const res = await fetch(client_portal_form_response_path(), {
      method: 'PATCH',
      headers: { 'Content-Type': 'application/json' },
      credentials: 'same-origin',
      body: JSON.stringify(payload)
    });

    if (res.ok) {
      if (validate) {
        // server returns a redirect (See Other). Navigate to confirmation page.
        // Some environments may follow redirects; explicitly navigate to the confirmation URL.
        window.location.href = '/client_portal/confirmation';
        return;
      } else {
        const json = await res.json();
        statusMessage = `Saved (version ${json.version})`;
      }
    } else {
      statusMessage = 'Save failed';
    }
  }
</script>

<main class="container">
  <h1>{form?.name}</h1>
  <p>Client: {client?.name}</p>

  <form onsubmit={(e) => { e.preventDefault(); save(false); }}>
    {#each form.form_fields as ff (ff.id)}
      <div class="field">
        <label for={"field-" + ff.id}>{ff.label}{ff.required ? ' *' : ''}</label>

        {#if ff.field_type === 'textarea'}
          <textarea id={"field-" + ff.id} bind:value={data[ff.id]} rows="4"></textarea>
        {:else if ff.field_type === 'number'}
          <input id={"field-" + ff.id} type="number" bind:value={data[ff.id]} />
        {:else if ff.field_type === 'date'}
          <input id={"field-" + ff.id} type="date" bind:value={data[ff.id]} />
        {:else}
          <input id={"field-" + ff.id} type="text" bind:value={data[ff.id]} />
        {/if}
      </div>
    {/each}

    <div class="actions">
      <button type="submit">Save</button>
      <button type="button" onclick={() => save(true)}>Submit & Validate</button>
    </div>
  </form>

  {#if statusMessage}
    <div class="status">{statusMessage}</div>
  {/if}
</main>