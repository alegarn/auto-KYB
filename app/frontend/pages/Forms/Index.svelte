<script lang="ts">
	import { onMount } from "svelte";
	import * as Sidebar from "/components/ui/sidebar/index.js";
	import AppSidebar from "/components/customs/app-sidebar.svelte";
	import * as Card from "/components/ui/card";
	import { Button, buttonVariants } from "/components/ui/button";
	import { Input } from "/components/ui/input";
	import * as Sheet from "/components/ui/sheet";
	import { Skeleton } from "/components/ui/skeleton";

	type FormStatus = "draft" | "submitted" | "approved" | "rejected";
	type Form = {
		id: string;
		name: string;
		status: FormStatus;
		created_at: string;
		owner: string;
	};

	let { children, user, session_id } = $props();

	const mockForms: Form[] = [
		{
			id: "FR-194",
			name: "Vendor Onboarding",
			status: "submitted",
			created_at: "2026-01-25",
			owner: "Mia Carter",
		},
		{
			id: "FR-195",
			name: "KYB Renewal",
			status: "approved",
			created_at: "2026-01-24",
			owner: "Evan Lee",
		},
		{
			id: "FR-196",
			name: "Risk Review",
			status: "draft",
			created_at: "2026-01-22",
			owner: "Mia Carter",
		},
		{
			id: "FR-197",
			name: "Partner Intake",
			status: "rejected",
			created_at: "2026-01-20",
			owner: "Noah Patel",
		},
		{
			id: "FR-198",
			name: "Supplier Compliance",
			status: "submitted",
			created_at: "2026-01-18",
			owner: "Lena Dubois",
		},
	];

	const statusFilters = ["all", "draft", "submitted", "approved", "rejected"] as const;
	type StatusFilter = (typeof statusFilters)[number];

	let forms = $state<Form[]>([]);
	let loading = $state(true);
	let search = $state("");
	let selectedStatus = $state<StatusFilter>("all");

	onMount(() => {
		const timeout = setTimeout(() => {
			forms = mockForms;
			loading = false;
		}, 650);

		return () => clearTimeout(timeout);
	});

	const filteredForms = $derived.by(() =>
		forms.filter((form) => {
			const matchesSearch = [form.name, form.id, form.owner]
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
</script>

<Sidebar.Provider>
	<AppSidebar session_id={session_id} />
	<main class="min-h-screen bg-muted/40 px-4 py-6 md:px-8 flex-grow">
		<Sidebar.Trigger class="mb-4" />
		{@render children?.()}

		<section class="flex flex-col gap-4 md:flex-row md:items-center md:justify-between">
			<div>
				<p class="text-sm text-muted-foreground">Workspace</p>
				<h1 class="text-2xl font-semibold text-foreground">My Forms</h1>
				<p class="text-sm text-muted-foreground">{user?.email}</p>
			</div>
			<div class="flex flex-col gap-2 sm:flex-row">
				<Button variant="secondary">Review submissions</Button>
				<Sheet.Root>
					<Sheet.Trigger class={buttonVariants({ variant: "default" })}>
						New form
					</Sheet.Trigger>
					<Sheet.Content side="right" class="w-full sm:max-w-lg">
						<Sheet.Header>
							<Sheet.Title>Create a new form</Sheet.Title>
							<Sheet.Description>
								Start with a form name and assign an owner. You can add fields later.
							</Sheet.Description>
						</Sheet.Header>
						<div class="mt-6 space-y-4">
							<div class="space-y-2">
								<label class="text-sm font-medium" for="form-name">Form name</label>
								<Input id="form-name" placeholder="KYB Renewal" />
							</div>
							<div class="space-y-2">
								<label class="text-sm font-medium" for="form-owner">Owner</label>
								<Input id="form-owner" placeholder="mia@quickkyb.com" type="email" />
							</div>
							<div class="space-y-2">
								<label class="text-sm font-medium" for="form-due">Due date</label>
								<Input id="form-due" type="date" />
							</div>
						</div>
						<Sheet.Footer class="mt-6">
							<Sheet.Close class={buttonVariants({ variant: "secondary" })}>
								Cancel
							</Sheet.Close>
							<Sheet.Close class={buttonVariants({ variant: "default" })}>
								Create form
							</Sheet.Close>
						</Sheet.Footer>
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
						<div class="flex flex-wrap gap-2">
							{#each statusFilters as status}
								<Button
									size="sm"
									variant={selectedStatus === status ? "default" : "secondary"}
									on:click={() => (selectedStatus = status)}
								>
									{labelForStatus(status)}
								</Button>
							{/each}
						</div>
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
									<div>
										<p class="font-medium text-foreground">{form.name}</p>
										<p class="text-sm text-muted-foreground">
											{form.id} · {form.created_at} · Owner: {form.owner}
										</p>
									</div>
									<div class="flex items-center gap-3">
										<span class={`rounded-full px-2.5 py-1 text-xs font-semibold ${statusBadge(form.status)}`}>
											{form.status}
										</span>
										<Button variant="secondary" size="sm">Open</Button>
									</div>
								</div>
							{/each}
						</div>
					{/if}
				</Card.Content>
			</Card.Root>
		</section>
	</main>
</Sidebar.Provider>
