<script lang="ts">
  import type { FormSettings } from "./types";
  import { Input } from "@/components/ui/input/index.js";
  import { Label } from "@/components/ui/label/index.js";

  interface Props {
    settings: FormSettings;
    onupdate?: (settings: FormSettings) => void;
  }

  const { settings, onupdate }: Props = $props();

  function updateSetting<K extends keyof FormSettings>(key: K, value: FormSettings[K]) {
    onupdate?.({ ...settings, [key]: value });
  }

  const defaultColors = {
    primary: '#2563eb',
    form_background: '#ffffff',
    header_background: '#f8fafc',
  };
</script>

<aside class="rounded-lg border bg-card w-full max-w-full box-border">
  <div class="border-b px-4 py-3">
    <h3 class="text-sm font-semibold">Form Styling</h3>
    <p class="text-xs text-muted-foreground">Customize form appearance</p>
  </div>

  <div class="space-y-4 p-4">
    <div>
      <Label for="cfg-primary-color" class="mb-1.5 block text-xs font-medium">Primary Color</Label>
      <div class="flex items-center gap-2">
        <input
          id="cfg-primary-color"
          type="color"
          value={settings.primary_color || defaultColors.primary}
          oninput={(e: any) => updateSetting('primary_color', e.target.value)}
          class="size-8 cursor-pointer rounded border border-input"
        />
        <Input
          value={settings.primary_color || defaultColors.primary}
          oninput={(e: any) => updateSetting('primary_color', e.target.value)}
          class="h-8 flex-1 text-sm font-mono"
          placeholder="#2563eb"
        />
      </div>
      <p class="mt-1 text-[11px] text-muted-foreground">Used for buttons and accents</p>
    </div>

    <div>
      <Label for="cfg-form-bg" class="mb-1.5 block text-xs font-medium">Form Background</Label>
      <div class="flex items-center gap-2">
        <input
          id="cfg-form-bg"
          type="color"
          value={settings.form_background_color || defaultColors.form_background}
          oninput={(e: any) => updateSetting('form_background_color', e.target.value)}
          class="size-8 cursor-pointer rounded border border-input"
        />
        <Input
          value={settings.form_background_color || defaultColors.form_background}
          oninput={(e: any) => updateSetting('form_background_color', e.target.value)}
          class="h-8 flex-1 text-sm font-mono"
          placeholder="#ffffff"
        />
      </div>
    </div>

    <div>
      <Label for="cfg-header-bg" class="mb-1.5 block text-xs font-medium">Header Background</Label>
      <div class="flex items-center gap-2">
        <input
          id="cfg-header-bg"
          type="color"
          value={settings.header_background_color || defaultColors.header_background}
          oninput={(e: any) => updateSetting('header_background_color', e.target.value)}
          class="size-8 cursor-pointer rounded border border-input"
        />
        <Input
          value={settings.header_background_color || defaultColors.header_background}
          oninput={(e: any) => updateSetting('header_background_color', e.target.value)}
          class="h-8 flex-1 text-sm font-mono"
          placeholder="#f8fafc"
        />
      </div>
      <p class="mt-1 text-[11px] text-muted-foreground">Background color for form header area</p>
    </div>

    <div class="rounded-lg border border-dashed p-3">
      <p class="mb-2 text-xs font-medium">Preview</p>
      <div
        class="overflow-hidden rounded-md border"
        style="background-color: {settings.form_background_color || defaultColors.form_background}"
      >
        <div
          class="px-3 py-2"
          style="background-color: {settings.header_background_color || defaultColors.header_background}"
        >
          <div class="h-2 w-20 rounded bg-gray-300"></div>
        </div>
        <div class="space-y-2 p-3">
          <div class="h-2 w-24 rounded bg-gray-200"></div>
          <div class="h-6 rounded border bg-white"></div>
          <button
            type="button"
            class="mt-2 rounded px-3 py-1 text-xs text-white"
            style="background-color: {settings.primary_color || defaultColors.primary}"
          >
            Submit
          </button>
        </div>
      </div>
    </div>

    <button
      type="button"
      class="w-full rounded-md border border-input px-3 py-1.5 text-xs text-muted-foreground transition-colors hover:bg-accent hover:text-foreground"
      onclick={() => onupdate?.({
        primary_color: defaultColors.primary,
        form_background_color: defaultColors.form_background,
        header_background_color: defaultColors.header_background,
      })}
    >
      Reset to Defaults
    </button>
  </div>
</aside>
