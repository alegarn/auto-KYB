import { clsx, type ClassValue } from "clsx"
import { twMerge } from "tailwind-merge"

export function cn(...inputs: ClassValue[]) {
  return twMerge(clsx(inputs))
}

// Lightweight helper types used across UI components.
// Updated to better match component templates that use generics
// and flexible rest props (e.g. `viewTransition`, `useInertia`, `ref`).
// WithElementRef accepts either a raw element (E | null) for `ref`
// or a callback setter (el: E) => void, matching common usage
// where components bind `ref = $bindable(null)` and then
// use <element bind:this={ref}>.
export type WithElementRef<T = Record<string, any>, E = Element | null> = T & Record<string, any> & {
  // allow either an element instance, null, or a setter callback
  elementRef?: E | null | ((el: E | null) => void)
  // many components bind `ref` to the element instance; accept element | null | setter
  ref?: E | null | ((el: E | null) => void)
}

/**
 * Checks if a specific field has errors in the standard rails-inertia error object.
 */
export function hasError(errors: any, field: string): boolean {
  if (!errors) return false;
  if (Array.isArray(errors)) return false;
  return (errors[field] && errors[field].length) > 0;
}

/**
 * Safely extracts the pathname from a URL string, handling relative paths and 
 * avoiding hardcoded hostnames that might be flagged by browsers.
 */
export function getPathname(url: string | undefined | null): string {
  if (!url) return "";
  try {
    // We use a dummy base for relative URLs, but window.location.origin is preferred if available
    const base = typeof window !== 'undefined' ? window.location.origin : 'https://a';
    return new URL(url, base).pathname;
  } catch {
    return url;
  }
}

// Generic alias allowing unknown extra props/events to be passed through.
export type ElementProps<T = Record<string, any>, E = Element | null> = WithElementRef<T, E> & Record<string, any>

export type WithoutChildren<T = any> = T
export type WithoutChildrenOrChild<T = any> = T
export type WithoutChildrenOrChildOrSomething<T = any> = T
