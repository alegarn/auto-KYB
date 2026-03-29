<script lang="ts">
  import * as Sidebar from "/components/ui/sidebar/index.js";
  import CalendarIcon from "@lucide/svelte/icons/calendar";
  import HouseIcon from "@lucide/svelte/icons/house";
  import SettingsIcon from "@lucide/svelte/icons/settings";
  import UsersIcon from "@lucide/svelte/icons/users";
  import BookOpenIcon from "@lucide/svelte/icons/book-open";
  import ArrowRightLeftIcon from "@lucide/svelte/icons/arrow-right-left";
  import { Link, page } from "@inertiajs/svelte";
  import { clients_path, dashboard_path, forms_path, quickstart_path } from "@/routes";

  // Menu items.
  const items = [
    {
      title: "Dashboard",
      url: dashboard_path(),
      icon: HouseIcon,
    },
    {
      title: "Quickstart",
      url: quickstart_path(),
      icon: BookOpenIcon,
    },
    {
      title: "My Forms",
      url: forms_path(),
      icon: CalendarIcon,
    },
    {
      title: "My Clients",
      url: clients_path(),
      icon: UsersIcon,
    },
    {
      title: "CRM Transfers",
      url: "/crm_transfers",
      icon: ArrowRightLeftIcon,
    },
    {
      title: "Settings",
      url: "/settings",
      icon: SettingsIcon,
    },
  ];

  const filteredItems = $derived(
    items.filter(item => 
      item.title !== "CRM Transfers" || ($page.props.auth as any)?.user?.can_use_crm
    )
  );

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
  <Sidebar.Content>
    <Sidebar.Group>
      <Sidebar.GroupLabel>Application</Sidebar.GroupLabel>
      <Sidebar.GroupContent>
        <Sidebar.Menu>
          {#each filteredItems as item (item.title)}
            <Sidebar.MenuItem>
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
            </Sidebar.MenuItem>
          {/each}
          <Sidebar.MenuItem>
            <Sidebar.MenuButton>
              <Link 
                href={`/sessions/${session_id}`} 
                method="delete" 
                as="button" 
                class="flex items-center gap-2 clickable text-destructive "
                viewTransition
              >
                Logout
              </Link>
            </Sidebar.MenuButton>
          </Sidebar.MenuItem>
        </Sidebar.Menu>
      </Sidebar.GroupContent>
    </Sidebar.Group>
  </Sidebar.Content>
</Sidebar.Root>