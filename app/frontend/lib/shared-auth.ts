import { page } from "@inertiajs/svelte";
import type { SharedAuth } from "../types/shared-auth";

export function getSharedAuth(): SharedAuth {
  return (page as any).props.auth as SharedAuth;
}
