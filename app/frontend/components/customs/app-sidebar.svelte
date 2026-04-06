<script lang="ts">
  import * as Sidebar from "/components/ui/sidebar/index.js";
  import * as Tooltip from "@/components/ui/tooltip/index.js";
  import CalendarIcon from "@lucide/svelte/icons/calendar";
  import HouseIcon from "@lucide/svelte/icons/house";
  import SettingsIcon from "@lucide/svelte/icons/settings";
  import UsersIcon from "@lucide/svelte/icons/users";
  import BookOpenIcon from "@lucide/svelte/icons/book-open";
  import ArrowRightLeftIcon from "@lucide/svelte/icons/arrow-right-left";
  import LogOutIcon from "@lucide/svelte/icons/log-out";
  import { Link, page } from "@inertiajs/svelte";
  import { crmAllowed, getSharedAuth } from "@/lib/shared-auth";
  import { clients_path, dashboard_path, forms_path, quickstart_path } from "@/routes";

  // Menu items.
  const items = [
    {
      title: "Dashboard",
      url: dashboard_path(),
      icon: HouseIcon,
      group: "Application",
    },
    {
      title: "My Forms",
      url: forms_path(),
      icon: CalendarIcon,
      group: "Application",
    },
    {
      title: "My Clients",
      url: clients_path(),
      icon: UsersIcon,
      group: "Application",
    },
    {
      title: "CRM Transfers",
      url: "/crm_transfers",
      icon: ArrowRightLeftIcon,
      group: "Integration",
    },
    {
      title: "Quickstart",
      url: quickstart_path(),
      icon: BookOpenIcon,
      group: "Resources",
    },
    {
      title: "Settings",
      url: "/settings",
      icon: SettingsIcon,
      group: "Account",
    },
  ];

  const sharedAuth = $derived(getSharedAuth($page?.props as Record<string, unknown>));
  const canUseCrm = $derived(crmAllowed(sharedAuth));

  const filteredItems = $derived(
    items.filter(item => 
      item.title !== "CRM Transfers" || true // Now we show CRM Transfers even if not allowed
    )
  );

  const mainItems = $derived(filteredItems.filter(i => i.group === "Application"));
  const integrationItems = $derived(filteredItems.filter(i => i.group === "Integration"));
  const resourceItems = $derived(filteredItems.filter(i => i.group === "Resources"));
  const accountItems = $derived(filteredItems.filter(i => i.group === "Account"));

  const currentPath = $derived.by(() => {
    const url = $page?.url ?? "";
    try {
      return new URL(url, "http://localhost").pathname;
    } catch {
      return url;
    }
  });

  const isActiveRoute = (url: string) => {
    if (!url || url === "#") return false;
    return currentPath === url || currentPath.startsWith(`${url}/`);
  };

  const crmSignals = $derived(($page?.props as any)?.crm_transfer_signals);
  const unreadFailedCount = $derived(crmSignals?.unread_failed_count ?? 0);
  const badgeLabel = $derived(unreadFailedCount > 99 ? '99+' : `${unreadFailedCount}`);

  let { session_id } = $props();
</script>
 
<Sidebar.Root>
  {#if sharedAuth?.user}
    <Sidebar.Header class="p-4">
      <div class="flex items-center gap-2 px-2 py-1.5">
        <div class="flex aspect-square size-8 items-center justify-center rounded-lg bg-primary text-primary-foreground">
          <HouseIcon class="size-4" />
        </div>
        <div class="flex flex-col gap-0.5 leading-none">
          <span class="font-semibold text-sm">Quick KYB</span>
          <span class="text-xs text-muted-foreground">{sharedAuth.user.email}</span>
        </div>
      </div>
    </Sidebar.Header>
  {/if}

  <Sidebar.Content>
    <Sidebar.Group>
      <Sidebar.GroupLabel>Application</Sidebar.GroupLabel>
      <Sidebar.GroupContent>
        <Sidebar.Menu>
          {#each mainItems as item (item.title)}
            <Sidebar.MenuItem>
              <Sidebar.MenuButton isActive={isActiveRoute(item.url)}>
                {#snippet child({ props }: { props: Record<string, unknown> })}
                  <Link href={item.url} {...props} viewTransition>
                    <item.icon />
                    <span>{item.title}</span>
                  </Link>
                {/snippet}
              </Sidebar.MenuButton>
            </Sidebar.MenuItem>
          {/each}
        </Sidebar.Menu>
      </Sidebar.GroupContent>
    </Sidebar.Group>

    <Sidebar.Group>
      <Sidebar.GroupLabel>Integrations</Sidebar.GroupLabel>
      <Sidebar.GroupContent>
        <Sidebar.Menu>
          {#each integrationItems as item (item.title)}
            <Sidebar.MenuItem>
              {#if item.title === 'CRM Transfers' && !canUseCrm}
                <Tooltip.Provider>
                  <Tooltip.Root>
                    <Tooltip.Trigger class="w-full">
                      <Sidebar.MenuButton disabled class="opacity-50 cursor-not-allowed grayscale">
                        <item.icon />
                        <span>{item.title}</span>
                      </Sidebar.MenuButton>
                    </Tooltip.Trigger>
                    <Tooltip.Content side="right">
                      <p class="max-w-64 text-xs">
                        You should upgrade your subscription to access this feature. Go to "Settings" -> "Manage subscription" to upgrade it.
                      </p>
                    </Tooltip.Content>
                  </Tooltip.Root>
                </Tooltip.Provider>
              {:else}
                <Sidebar.MenuButton isActive={isActiveRoute(item.url)}>
                  {#snippet child({ props }: { props: Record<string, unknown> })}
                    <Link href={item.url} {...props} viewTransition>
                      <item.icon />
                      <span>{item.title}</span>
                    </Link>
                  {/snippet}
                </Sidebar.MenuButton>
                {#if item.title === 'CRM Transfers' && unreadFailedCount > 0}
                  <Sidebar.MenuBadge
                    class="bg-destructive text-white ring-1 ring-destructive/30 shadow-sm"
                    aria-label={`${badgeLabel} failed CRM transfers`}
                  >{badgeLabel}</Sidebar.MenuBadge>
                {/if}
              {/if}
            </Sidebar.MenuItem>
          {/each}
        </Sidebar.Menu>
      </Sidebar.GroupContent>
    </Sidebar.Group>

    <Sidebar.Group>
      <Sidebar.GroupLabel>Resources</Sidebar.GroupLabel>
      <Sidebar.GroupContent>
        <Sidebar.Menu>
          {#each resourceItems as item (item.title)}
            <Sidebar.MenuItem>
              <Sidebar.MenuButton>
                {#snippet child({ props }: { props: Record<string, unknown> })}
                  <Link 
                    href={item.url} 
                    {...props} 
                    target="_blank" 
                    rel="noopener noreferrer"
                  >
                    <item.icon />
                    <span>{item.title}</span>
                  </Link>
                {/snippet}
              </Sidebar.MenuButton>
            </Sidebar.MenuItem>
          {/each}
        </Sidebar.Menu>
      </Sidebar.GroupContent>
    </Sidebar.Group>
  </Sidebar.Content>

  <Sidebar.Footer>
    <Sidebar.Group>
      <Sidebar.Menu>
        {#each accountItems as item (item.title)}
          <Sidebar.MenuItem>
            <Sidebar.MenuButton isActive={isActiveRoute(item.url)}>
              {#snippet child({ props }: { props: Record<string, unknown> })}
                <Link href={item.url} {...props} viewTransition>
                  <item.icon />
                  <span>{item.title}</span>
                </Link>
              {/snippet}
            </Sidebar.MenuButton>
          </Sidebar.MenuItem>
        {/each}
        <Sidebar.MenuItem>
          <Sidebar.MenuButton>
            {#snippet child({ props })}
              <Link 
                href={`/sessions/${session_id}`} 
                method="delete" 
                as="button" 
                class="flex items-center gap-2 clickable text-destructive hover:bg-destructive/10 hover:text-destructive w-full"
                {...props}
              >
                <LogOutIcon class="size-4" />
                <span>Logout</span>
              </Link>
            {/snippet}
          </Sidebar.MenuButton>
        </Sidebar.MenuItem>
      </Sidebar.Menu>
    </Sidebar.Group>
  </Sidebar.Footer>
</Sidebar.Root>
