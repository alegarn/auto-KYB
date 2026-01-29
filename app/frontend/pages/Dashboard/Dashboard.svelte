<script lang="ts">
  import * as Sidebar from "/components/ui/sidebar/index.js";
  import AppSidebar from "/components/customs/app-sidebar.svelte";
  import { page } from '@inertiajs/svelte'
  console.log($page.props) // inspect keys sent by server

  let { children, user, session_id } = $props();
  /* add hydration later https://inertia-rails.dev/guide/server-side-rendering*/

</script>
 
<Sidebar.Provider>
 <AppSidebar session_id={session_id} />
 <main>
  <Sidebar.Trigger />
  {@render children?.()}
  <p> Hello {user?.email}</p>
  <p> Session ID: {session_id}</p>
 </main>
</Sidebar.Provider>