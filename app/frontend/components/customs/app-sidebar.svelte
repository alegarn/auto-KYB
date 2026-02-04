<script lang="ts">
  import * as Sidebar from "/components/ui/sidebar/index.js";
  import CalendarIcon from "@lucide/svelte/icons/calendar";
  import HouseIcon from "@lucide/svelte/icons/house";
  import SettingsIcon from "@lucide/svelte/icons/settings";
  import UsersIcon from "@lucide/svelte/icons/users";
  import { Link, page } from "@inertiajs/svelte";
  import { clients_path, dashboard_path, forms_path } from "/routes/index";

  // Menu items.
  const items = [
    {
      title: "Dashboard",
      url: dashboard_path(),
      icon: HouseIcon,
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
      title: "Settings",
      url: "/settings",
      icon: SettingsIcon,
    },
  ];

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

  let { session_id } = $props();
</script>
 
<Sidebar.Root>
  <Sidebar.Content>
    <Sidebar.Group>
      <Sidebar.GroupLabel>Application</Sidebar.GroupLabel>
      <Sidebar.GroupContent>
        <Sidebar.Menu>
          {#each items as item (item.title)}
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