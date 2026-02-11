<script lang="ts">
  type Option = { label: string; value: string | number; disabled?: boolean; id?: string };

  const { options = [], multiple = false, name = '', required = false, className = '', onChange, onValue, value } = $props();

  let containerEl: HTMLElement | null = null;

  // keep optionEls in sync with rendered buttons using Svelte 5 derived rune
  let optionEls = $derived.by((): HTMLElement[] => (containerEl ? Array.from(containerEl.querySelectorAll('button')) as HTMLElement[] : []));

  // local mutable copy of the prop value to avoid using $set
  // mutable local value (keeps in sync with `value` prop)
  // initialize without referencing props to avoid Svelte capture warnings
  let localValue = $state(null as any);

  $effect(() => {
    if (multiple) {
      localValue = Array.isArray(value) ? value : [];
    } else {
      localValue = value ?? null;
    }
  });

  function emit(newVal?: any) {
    const v = newVal === undefined ? localValue : newVal;
    // Call callback props for Svelte-5 style consumers.
    onChange?.(v);
    onValue?.(v);
  }

  function isSelected(opt: Option) {
    const v = localValue;
    return multiple ? (Array.isArray(v) && v.indexOf(opt.value) !== -1) : v === opt.value;
  }

  function toggleOption(opt: Option) {
    if (opt.disabled) return;
    if (multiple) {
      const v = localValue || [];
      const i = v.indexOf(opt.value);
      const next = i === -1 ? [...v, opt.value] : v.filter((val: any) => val !== opt.value);
      localValue = next;
      emit(next);
    } else {
      const curr = localValue;
      const next = opt.value === curr ? null : opt.value;
      localValue = next;
      emit(next);
    }
  }

  function focusIndex(i: number) {
    if (optionEls[i]) optionEls[i].focus();
  }

  function handleKeyDown(e: KeyboardEvent, idx: number, opt: Option) {
    const key = e.key;
    if (!multiple) {
      if (key === 'ArrowRight' || key === 'ArrowDown') {
        e.preventDefault();
        focusIndex((idx + 1) % options.length);
      } else if (key === 'ArrowLeft' || key === 'ArrowUp') {
        e.preventDefault();
        focusIndex((idx - 1 + options.length) % options.length);
      } else if (key === ' ' || key === 'Enter') {
        e.preventDefault();
        toggleOption(opt);
      }
    } else {
      if (key === ' ' || key === 'Enter') {
        e.preventDefault();
        toggleOption(opt);
      }
    }
  }
</script>

<div
  bind:this={containerEl}
  class="buttons-field {className}"
    role={multiple ? 'group' : 'radiogroup'}
    aria-required={required}
    aria-label={name}
  >
    {#each options as opt, i}
      <button
        type="button"
        class="btn {isSelected(opt) ? 'btn--selected' : ''} {opt.disabled ? 'btn--disabled' : ''}"
        role={multiple ? 'checkbox' : 'radio'}
        aria-checked={isSelected(opt)}
        aria-disabled={opt.disabled}
        tabindex="0"
        onclick={() => toggleOption(opt)}
        onkeydown={(e) => handleKeyDown(e, i, opt)}
      >
        {opt.label}
      </button>
      {#if name && isSelected(opt)}
        {#if multiple}
          <input type="hidden" name={name} value={opt.value} />
        {:else}
          <input type="hidden" name={name} value={opt.value} />
        {/if}
      {/if}
    {/each}
  </div>

  <style>
    .buttons-field { display:flex; gap:0.5rem; flex-wrap:wrap; }
    .btn {
      padding:0.45rem 0.75rem;
      border:1px solid var(--border-color, #cfcfcf);
      background:var(--bg, #fff);
      cursor:pointer;
      border-radius:6px;
      outline:none;
    }
    .btn:focus { box-shadow:0 0 0 3px rgba(0,123,255,0.18); }
    .btn--selected {
      background:#0b74de;
      color:#fff;
      border-color:#075fa8;
    }
    .btn--disabled { opacity:0.5; cursor:not-allowed; }
  </style>
