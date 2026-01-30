<script lang="ts">
  import { Card, CardContent, CardHeader } from "/components/ui/card";
  import CardDecorator from "/components/ui/card-decorator/card-decorator.svelte";
  import FileText from "@lucide/svelte/icons/file-text";
  import UploadCloud from "@lucide/svelte/icons/upload-cloud";
  import Zap from "@lucide/svelte/icons/zap";
</script>

<section class="bg-zinc-50 py-16 md:py-32 dark:bg-transparent">
  <div class="@container mx-auto max-w-5xl px-6">
    <div class="text-center">
      <h2 class="text-balance text-4xl font-semibold lg:text-5xl">
        Launch branded forms that close faster
      </h2>
      <p class="mt-4">
        Create client-ready forms in minutes—share via one link, auto-fill KYB/KYC to speed approvals, and export them to your CRM!
      </p>
    </div>
    <div
      class="@min-4xl:max-w-full @min-4xl:grid-cols-3 mx-auto mt-8 grid max-w-sm gap-6 *:text-center md:mt-16"
    >
      <Card class="group shadow-zinc-950/5">
        <CardHeader class="pb-3">
          <CardDecorator>
            <FileText class="size-6" aria-hidden />
          </CardDecorator>

          <h3 class="mt-6 font-medium">Tailored forms</h3>
        </CardHeader>

        <CardContent>
          <p class="text-sm">
            Create tailored intake forms in minutes and send them to clients with a single link.
          </p>
        </CardContent>
      </Card>

      <Card class="group shadow-zinc-950/5">
        <CardHeader class="pb-3">
          <CardDecorator>
            <UploadCloud class="size-6" aria-hidden />
          </CardDecorator>

          <h3 class="mt-6 font-medium">Export & CRM sync</h3>
        </CardHeader>

        <CardContent>
          <p class="mt-3 text-sm">
            One-click CSV export or automated uploads to your CRM.
          </p>
        </CardContent>
      </Card>

      <Card class="group shadow-zinc-950/5">
        <CardHeader class="pb-3">
          <CardDecorator>
            <Zap class="size-6" aria-hidden />
          </CardDecorator>

          <h3 class="mt-6 font-medium">Auto pre-fill KYB/KYC</h3>
        </CardHeader>

        <CardContent>
          <p class="mt-3 text-sm">
            Automatically complete KYB/KYC fields using client metadata — faster approvals, fewer mistakes.
          </p>
        </CardContent>
      </Card>
    </div>
  </div>
</section>