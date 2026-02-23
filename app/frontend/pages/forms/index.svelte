<script lang="ts">
	import * as Card from "/components/ui/card";
	import { Button, buttonVariants } from "/components/ui/button";
	import { Input } from "/components/ui/input";
	import * as Sheet from "/components/ui/sheet";
	import { Skeleton } from "/components/ui/skeleton";
	import { Form as InertiaForm, inertia, useForm } from '@inertiajs/svelte'
	import Modal from "/components/ui/modal.svelte";
	import { new_form_path, form_path, edit_form_path, duplicate_form_path } from "@/routes";
	import { page } from '@inertiajs/svelte'
	import Toast from "/components/customs/Toast.svelte"
	import { Copy } from "@lucide/svelte";

	type FormStatus = "draft" | "submitted" | "approved" | "rejected";
	type Form = {
		id: string;
		name: string;
		status: FormStatus;
		created_at: string;
    updated_at: string;
	};

	let { user, forms: serverForms, active_form_ids: serverActiveFormIds } = $props();
  let showModal = $state(false);
  let selectedToDelete = $state(null as Form | null);

  const deleteForm = useForm({});
  const duplicateFormAction = useForm({});

  function openDeleteModal(f: Form) {
    selectedToDelete = f;
    showModal = true;
  }

  function confirmDelete() {
    if (!selectedToDelete) return;
    $deleteForm.delete(form_path(selectedToDelete.id), {
      onSuccess: () => {
        selectedToDelete = null;
        showModal = false;
      },
    });
  }

  function duplicateForm(f: Form) {
    $duplicateFormAction.post(duplicate_form_path(f.id));
  }

	const statusFilters = ["all", "draft", "submitted", "approved", "rejected"] as const;
	type StatusFilter = (typeof statusFilters)[number];

	// Use server-provided list instead of mock data
	let forms = $derived<Form[]>(serverForms || []);
	const activeFormIdSet = $derived(
		new Set((serverActiveFormIds || []) as string[])
	);
	const selectedIsActive = $derived.by(
		() => (selectedToDelete ? activeFormIdSet.has(selectedToDelete.id) : false)
	);
	let loading = $state(false);
	let search = $state("");
	let selectedStatus = $state<StatusFilter>("all");

	const filteredForms = $derived.by(() =>
		forms.filter((form) => {
			const matchesSearch = [form.name, form.id]
				.join(" ")
				.toLowerCase()
				.includes(search.trim().toLowerCase());
			const matchesStatus = selectedStatus === "all" ? true : form.status === selectedStatus;
			return matchesSearch && matchesStatus;
		})
	);

	const totalForms = $derived.by(() => forms.length);
	const draftForms = $derived.by(() => forms.filter((form) => form.status === "draft").length);
	const submittedForms = $derived.by(() => forms.filter((form) => form.status === "submitted").length);
	const approvedForms = $derived.by(() => forms.filter((form) => form.status === "approved").length);

	const statusBadge = (status: FormStatus) => {
		switch (status) {
			case "approved":
				return "bg-emerald-100 text-emerald-700";
			case "submitted":
				return "bg-blue-100 text-blue-700";
			case "rejected":
				return "bg-rose-100 text-rose-700";
			default:
				return "bg-amber-100 text-amber-700";
		}
	};

	const labelForStatus = (status: StatusFilter) => {
		if (status === "all") return "All";
		return status.charAt(0).toUpperCase() + status.slice(1);
	};

	// The Inertia `page.flash.toast` prop exists at runtime but the
	// upstream `FlashData` type doesn't include `toast`. This is a
	// false-positive TypeScript error; it's intentional and safe to
	// ignore here so the UI can read the runtime flash structure.
	// @ts-ignore: Property 'toast' does not exist on type 'FlashData'
	const flashToast: { message?: string; type?: string } | null = $derived($page?.flash?.toast ?? null);
</script>

{#if flashToast}
			<Toast message={flashToast.message} type={flashToast.type ?? 'notice'} />
		{/if}

		<section class="flex flex-col gap-4 md:flex-row md:items-center md:justify-between">
			<div>
				<p class="text-sm text-muted-foreground">Workspace</p>
				<h1 class="text-2xl font-semibold text-foreground">My Forms</h1>
				<p class="text-sm text-muted-foreground">{user?.email}</p>
			</div>
			<div class="flex flex-col gap-2 sm:flex-row">
				<!-- <Button variant="secondary">Review submissions</Button> -->
				<Sheet.Root>
					<Button href={new_form_path()} variant="default">
						New form
					</Button>
					<Sheet.Content side="right" class="w-full sm:max-w-lg">
						<Sheet.Header>
							<Sheet.Title>Create a new form</Sheet.Title>
							<Sheet.Description>
								Start with a form name and optional description. You can add fields later.
							</Sheet.Description>
						</Sheet.Header>
						<div class="mt-6">
							<!-- Use the Inertia Form to POST to /forms -->
							<InertiaForm action="/forms" method="post">
								<div class="space-y-4">
									<div class="space-y-2">
										<label class="text-sm font-medium" for="form-name">Form name</label>
										<Input id="form-name" name="form[name]" placeholder="KYB Renewal" />
									</div>
									<div class="space-y-2">
										<label class="text-sm font-medium" for="form-description">Description</label>
										<Input id="form-description" name="form[description]" placeholder="Optional description" />
									</div>
								</div>
								<Sheet.Footer class="mt-6">
									<Sheet.Close class={buttonVariants({ variant: "secondary" })}>
										Cancel
									</Sheet.Close>
									<button type="submit" class={buttonVariants({ variant: "default" })}>
										Create form
									</button>
								</Sheet.Footer>
							</InertiaForm>
						</div>
					</Sheet.Content>
				</Sheet.Root>
			</div>
		</section>

		<section class="mt-6 grid gap-4 md:grid-cols-2 xl:grid-cols-4">
			<Card.Root>
				<Card.Header>
					<Card.Title>Total forms</Card.Title>
					<Card.Description>Across all statuses</Card.Description>
				</Card.Header>
				<Card.Content>
					<p class="text-3xl font-semibold">{totalForms}</p>
				</Card.Content>
			</Card.Root>
			<Card.Root>
				<Card.Header>
					<Card.Title>Drafts</Card.Title>
					<Card.Description>In progress</Card.Description>
				</Card.Header>
				<Card.Content>
					<p class="text-3xl font-semibold">{draftForms}</p>
				</Card.Content>
			</Card.Root>
			<Card.Root>
				<Card.Header>
					<Card.Title>Submitted</Card.Title>
					<Card.Description>Awaiting review</Card.Description>
				</Card.Header>
				<Card.Content>
					<p class="text-3xl font-semibold">{submittedForms}</p>
				</Card.Content>
			</Card.Root>
			<Card.Root>
				<Card.Header>
					<Card.Title>Approved</Card.Title>
					<Card.Description>Ready to use</Card.Description>
				</Card.Header>
				<Card.Content>
					<p class="text-3xl font-semibold">{approvedForms}</p>
				</Card.Content>
			</Card.Root>
		</section>

		<section class="mt-6">
			<Card.Root>
				<Card.Header class="gap-3 sm:flex-row sm:items-center sm:justify-between">
					<div>
						<Card.Title>Forms list</Card.Title>
						<Card.Description>Manage and track form statuses.</Card.Description>
					</div>
					<div class="flex flex-col gap-2 sm:flex-row">
						<Input
							placeholder="Search forms"
							bind:value={search}
							class="sm:w-56"
						/>
						<!-- <div class="flex flex-wrap gap-2">
							{#each statusFilters as status}
								<Button
									size="sm"
									variant={selectedStatus === status ? "default" : "secondary"}
									onclick={() => (selectedStatus = status)}
								>
									{labelForStatus(status)}
								</Button>
							{/each}
						</div> -->
					</div>
				</Card.Header>
				<Card.Content class="space-y-3">
					{#if loading}
						{#each Array(4) as _}
							<div class="flex items-center justify-between gap-4">
								<div class="space-y-2">
									<Skeleton class="h-4 w-44" />
									<Skeleton class="h-3 w-28" />
								</div>
								<Skeleton class="h-8 w-20" />
							</div>
						{/each}
					{:else if filteredForms.length === 0}
						<div class="rounded-lg border border-dashed border-muted-foreground/30 p-6 text-center">
							<p class="text-sm font-medium">No forms found</p>
							<p class="text-sm text-muted-foreground">Create a new form or adjust your filters.</p>
						</div>
					{:else}
						<div class="max-h-[520px] space-y-3 overflow-auto pr-2">
							{#each filteredForms as form (form.id)}
								<div class="flex flex-col gap-3 rounded-lg border border-border bg-background p-4 sm:flex-row sm:items-center sm:justify-between">
									<a use:inertia href={form_path(form.id)} class="flex-1 no-underline">
										<p class="font-medium text-foreground">{form.name}</p>
										<p class="text-sm text-muted-foreground">Last update {form.updated_at}</p>
									</a>
									<div class="flex items-center gap-3">
										<span class={`rounded-full px-2.5 py-1 text-xs font-semibold ${statusBadge(form.status)}`}>
											{form.status}
										</span>
										<Button type="button" variant="ghost" size="icon" onclick={() => duplicateForm(form)} title="Duplicate form">
											<Copy class="h-4 w-4" />
										</Button>
										<Button href={edit_form_path(form.id)} class="no-underline" size="sm" variant="secondary">Update</Button>
										<Button type="button" variant="destructive" size="sm" onclick={() => openDeleteModal(form)}>Delete</Button>
									</div>
								</div>
							{/each}
						</div>
					{/if}
				</Card.Content>
			</Card.Root>
		</section>
<Modal bind:showModal={showModal} title="Delete form" description={selectedToDelete ? `Delete "${selectedToDelete.name}"?` : ''} onConfirm={confirmDelete} onClose={() => { selectedToDelete = null; showModal = false; }}>
	<p>Are you sure you want to delete "{selectedToDelete?.name}"?</p>
	{#if selectedIsActive}
		<p class="mt-2 text-sm text-amber-700">This form is active in one or more client portals. Deleting it will revoke access and remove saved responses on the server.</p>
	{:else}
		<p class="mt-2 text-sm text-muted-foreground">Deleting this form may prevent active clients from filling it. Update linked clients before deleting.</p>
	{/if}
</Modal>
