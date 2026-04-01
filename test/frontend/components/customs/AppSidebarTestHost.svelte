<script lang="ts">
  import * as Sidebar from "/components/ui/sidebar/index.js";
  import AppSidebar from "/components/customs/app-sidebar.svelte";

  let { session_id = 'test-session' } = $props();
</script>

<Sidebar.Provider>
  <AppSidebar {session_id} />
</Sidebar.Provider>
