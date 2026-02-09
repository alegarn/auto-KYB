<script lang="ts">
  import Input from "@/components/ui/input/input.svelte";
  import { Textarea } from "@/components/ui/textarea/index.js";
  import { Select, SelectTrigger, SelectContent, SelectItem } from "@/components/ui/select/index.js";
  import { RadioGroup, RadioGroupItem } from "@/components/ui/radio-group/index.js";
  import { Checkbox } from "@/components/ui/checkbox/index.js";
  import { Separator } from "@/components/ui/separator/index.js";
  import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from "@/components/ui/table/index.js";
  import { Label } from "@/components/ui/label/index.js";
  import { Plus, Trash2 } from "@lucide/svelte";
  import type { FieldType, FieldMetadata, TableColumn } from "./form-builder/types";

  interface Props {
    id: string;
    label: string;
    type: FieldType | string;
    required?: boolean;
    value?: any;
    name?: string;
    onChange?: (detail: { id: string; value: any }) => void;
    inputOnly?: boolean;
    metadata?: FieldMetadata;
  }

  const { id, label, type, required = false, value, name, onChange, inputOnly = false, metadata = {} }: Props = $props();

  let currentValue = $derived(value ?? '');
  let tableRows = $state<Record<string, any>[]>([{}]);
  let checkboxValues = $state<string[]>([]);

  $effect(() => {
    currentValue = value ?? '';
    if (type === 'table' && Array.isArray(value) && value.length > 0) {
      tableRows = value;
    } else if (type === 'table' && (!value || (Array.isArray(value) && value.length === 0))) {
      tableRows = [{}];
    }
    if (type === 'checkbox' && Array.isArray(value)) {
      checkboxValues = value;
    } else if (type === 'checkbox' && typeof value === 'string' && value) {
      checkboxValues = [value];
    }
  });

  function onInput(e: Event) {
    const target = e.target as HTMLInputElement;
    currentValue = target.value;
    onChange?.({ id, value: currentValue });
  }

  function onTextareaInput(e: Event) {
    const target = e.target as HTMLTextAreaElement;
    currentValue = target.value;
    onChange?.({ id, value: currentValue });
  }

  function onSelectChange(val: string | undefined) {
    currentValue = val ?? '';
    onChange?.({ id, value: currentValue });
  }

  function onRadioChange(val: string) {
    currentValue = val;
    onChange?.({ id, value: currentValue });
  }

  function onCheckboxChange(option: string, checked: boolean) {
    if (metadata.allow_multiple) {
      if (checked) {
        checkboxValues = [...checkboxValues, option];
      } else {
        checkboxValues = checkboxValues.filter((v) => v !== option);
      }
      onChange?.({ id, value: checkboxValues });
    } else {
      checkboxValues = checked ? [option] : [];
      onChange?.({ id, value: checked ? option : '' });
    }
  }

  function onTableCellChange(rowIndex: number, colKey: string, val: string) {
    tableRows[rowIndex] = { ...tableRows[rowIndex], [colKey]: val };
    onChange?.({ id, value: tableRows });
  }

  function addTableRow() {
    tableRows = [...tableRows, {}];
    onChange?.({ id, value: tableRows });
  }

  function removeTableRow(rowIndex: number) {
    if (tableRows.length > 1) {
      tableRows = tableRows.filter((_, i) => i !== rowIndex);
      onChange?.({ id, value: tableRows });
    }
  }

  function onFileChange(e: Event) {
    const target = e.target as HTMLInputElement;
    const file = target.files?.[0];
    onChange?.({ id, value: file ?? null });
  }

  const options = $derived(metadata.options ?? []);
  const columns = $derived<TableColumn[]>(metadata.columns ?? []);
  const placeholder = $derived(metadata.placeholder ?? '');
  const description = $derived(metadata.description ?? '');
  const fileConfig = $derived(metadata.file ?? {});
  const separatorConfig = $derived(metadata.separator ?? {});
  const textContent = $derived(metadata.text_content ?? '');

  const separatorMarginClass = $derived.by(() => {
    const margin = separatorConfig.margin ?? 'medium';
    if (margin === 'small') return 'my-2';
    if (margin === 'large') return 'my-8';
    return 'my-4';
  });
</script>

{#if type === 'text' || type === 'number' || type === 'email' || type === 'date'}
  {#if inputOnly}
    <Input
      aria-label={label}
      id={name ?? id}
      name={name}
      type={type}
      bind:value={currentValue}
      oninput={onInput}
      {required}
      placeholder={placeholder}
    />
  {:else}
    <label>
      {label}
      <Input
        aria-label={label}
        id={name ?? id}
        name={name}
        type={type}
        bind:value={currentValue}
        oninput={onInput}
        {required}
        placeholder={placeholder}
      />
    </label>
  {/if}

{:else if type === 'textarea'}
  {#if inputOnly}
    <Textarea
      aria-label={label}
      id={name ?? id}
      name={name}
      bind:value={currentValue}
      oninput={onTextareaInput}
      required={required}
      placeholder={placeholder}
    />
  {:else}
    <label>
      {label}
      <Textarea
        aria-label={label}
        id={name ?? id}
        name={name}
        bind:value={currentValue}
        oninput={onTextareaInput}
        required={required}
        placeholder={placeholder}
      />
    </label>
  {/if}

{:else if type === 'select'}
  <Select type="single" onValueChange={onSelectChange} value={currentValue || undefined}>
    <SelectTrigger class="w-full">
      <span data-slot="select-value">{currentValue || 'Select an option'}</span>
    </SelectTrigger>
    <SelectContent>
      {#each options as option (option)}
        <SelectItem value={option} label={option} />
      {/each}
    </SelectContent>
  </Select>
  {#if name}
    <input type="hidden" {name} value={currentValue} />
  {/if}

{:else if type === 'radio'}
  <RadioGroup value={currentValue} onValueChange={onRadioChange}>
    {#each options as option (option)}
      <div class="flex items-center gap-2">
        <RadioGroupItem value={option} id={`${id}-${option}`} />
        <Label for={`${id}-${option}`} class="font-normal">{option}</Label>
      </div>
    {/each}
  </RadioGroup>
  {#if name}
    <input type="hidden" {name} value={currentValue} />
  {/if}

{:else if type === 'checkbox'}
  <div class="space-y-2">
    {#each options as option (option)}
      <div class="flex items-center gap-2">
        <Checkbox
          id={`${id}-${option}`}
          checked={checkboxValues.includes(option)}
          onCheckedChange={(checked) => onCheckboxChange(option, checked === true)}
        />
        <Label for={`${id}-${option}`} class="font-normal">{option}</Label>
      </div>
    {/each}
  </div>
  {#if name}
    {#each checkboxValues as val (val)}
      <input type="hidden" name={name} value={val} />
    {/each}
  {/if}

{:else if type === 'table'}
  <div class="space-y-2">
    <div class="rounded-md border">
      <Table>
        <TableHeader>
          <TableRow>
            {#each columns as col (col.key)}
              <TableHead>{col.label}</TableHead>
            {/each}
            <TableHead class="w-12"></TableHead>
          </TableRow>
        </TableHeader>
        <TableBody>
          {#each tableRows as row, rowIndex (rowIndex)}
            <TableRow>
              {#each columns as col (col.key)}
                <TableCell>
                  <Input
                    type={col.type === 'number' ? 'number' : 'text'}
                    value={row[col.key] ?? ''}
                    oninput={(e) => onTableCellChange(rowIndex, col.key, (e.target as HTMLInputElement).value)}
                    class="h-8"
                  />
                </TableCell>
              {/each}
              <TableCell>
                <button
                  type="button"
                  class="p-1 text-muted-foreground hover:text-destructive disabled:opacity-50"
                  onclick={() => removeTableRow(rowIndex)}
                  disabled={tableRows.length <= 1}
                  aria-label="Remove row"
                >
                  <Trash2 class="size-4" />
                </button>
              </TableCell>
            </TableRow>
          {/each}
        </TableBody>
      </Table>
    </div>
    <button
      type="button"
      class="flex items-center gap-1 rounded px-2 py-1 text-sm text-primary hover:bg-accent"
      onclick={addTableRow}
    >
      <Plus class="size-4" /> Add Row
    </button>
  </div>
  {#if name}
    <input type="hidden" {name} value={JSON.stringify(tableRows)} />
  {/if}

{:else if type === 'file'}
  <Input
    aria-label={label}
    id={name ?? id}
    name={name}
    type="file"
    onchange={onFileChange}
    accept={fileConfig.allowed_types?.map((t) => `.${t}`).join(',')}
  />
  {#if fileConfig.allowed_types?.length}
    <p class="mt-1 text-xs text-muted-foreground">
      Allowed: {fileConfig.allowed_types.join(', ')}
      {#if fileConfig.max_size_kb}
        (max {Math.round(fileConfig.max_size_kb / 1024)}MB)
      {/if}
    </p>
  {/if}

{:else if type === 'section'}
  <div class="mt-6 mb-4 pb-2 border-b">
    <h2 class="text-lg font-semibold">{label}</h2>
    {#if description}
      <p class="text-sm text-muted-foreground">{description}</p>
    {/if}
  </div>

{:else if type === 'subtitle'}
  <div class="mt-4 mb-2">
    <h3 class="text-base font-medium">{label}</h3>
    {#if description}
      <p class="text-sm text-muted-foreground">{description}</p>
    {/if}
  </div>

{:else if type === 'static_text'}
  <div class="my-3 rounded-md bg-muted/50 p-3">
    <p class="text-sm text-muted-foreground">{textContent || description}</p>
  </div>

{:else if type === 'separator'}
  <Separator class={separatorMarginClass} />

{:else if type === 'logo'}
  {#if metadata.logo?.image_url}
    <div class="my-4" class:text-left={metadata.logo.alignment === 'left'} class:text-center={metadata.logo.alignment === 'center'} class:text-right={metadata.logo.alignment === 'right'}>
      <img
        src={metadata.logo.image_url}
        alt="Logo"
        style:width={metadata.logo.width ? `${metadata.logo.width}px` : 'auto'}
        style:height={metadata.logo.height ? `${metadata.logo.height}px` : 'auto'}
        class="inline-block"
      />
    </div>
  {/if}

{:else}
  {#if inputOnly}
    <Input
      aria-label={label}
      id={name ?? id}
      name={name}
      type="text"
      bind:value={currentValue}
      oninput={onInput}
      {required}
      placeholder={placeholder}
    />
  {:else}
    <label>
      {label}
      <Input
        aria-label={label}
        id={name ?? id}
        name={name}
        type="text"
        bind:value={currentValue}
        oninput={onInput}
        {required}
        placeholder={placeholder}
      />
    </label>
  {/if}
{/if}
