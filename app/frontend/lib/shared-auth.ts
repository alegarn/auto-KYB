import { page } from "@inertiajs/svelte";
import { get } from "svelte/store";
import type { SharedAuth } from "../types/shared-auth";

type SharedPageProps = Record<string, unknown> & {
  auth?: SharedAuth | null;
  session_id?: string | null;
};

export function getSharedAuth(pageProps?: Record<string, unknown> | null): SharedAuth | null {
  if (pageProps) {
    return (pageProps as SharedPageProps).auth ?? null;
  }

  const currentPage = get(page);
  return (currentPage?.props as SharedPageProps | undefined)?.auth ?? null;
}

export function crmAllowed(auth: SharedAuth | null | undefined): boolean {
  return !!auth?.features?.crm?.allowed;
}

export function getSharedSessionId(pageProps?: Record<string, unknown> | null): string | null {
  if (pageProps) {
    return (pageProps as SharedPageProps).session_id ?? null;
  }

  const currentPage = get(page);
  return (currentPage?.props as SharedPageProps | undefined)?.session_id ?? null;
}
