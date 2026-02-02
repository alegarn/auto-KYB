import { clsx, type ClassValue } from "clsx"
import { twMerge } from "tailwind-merge"

export function cn(...inputs: ClassValue[]) {
  return twMerge(clsx(inputs))
}

// Lightweight helper types used across UI components.
// These are flexible placeholders to satisfy TypeScript imports
// from component templates; refine as needed for stricter typing.
export type WithElementRef<T = any> = T & { elementRef?: (el: Element | null) => void }
export type WithoutChildren = Record<string, any>
export type WithoutChildrenOrChild = Record<string, any>
export type WithoutChildrenOrChildOrSomething = Record<string, any>
