import type { StorybookConfig } from '@storybook/svelte-vite';

const config: StorybookConfig = {
  stories: [
    // Explicitly include project root `stories/` directory
    "../stories/**/*.stories.svelte",
    // Project component and page stories
    "../app/frontend/components/**/*.stories.@(svelte|js|ts)",
    "../app/frontend/pages/**/*.stories.@(svelte|js|ts)",
    // Default storybook template locations (kept for compatibility)
    "../stories/**/*.mdx",
    "../stories/**/*.stories.@(js|ts|svelte)"
  ],
  addons: [
    "@storybook/addon-svelte-csf",
    "@chromatic-com/storybook",
    "@storybook/addon-vitest",
    "@storybook/addon-a11y",
    "@storybook/addon-docs"
  ],
  framework: "@storybook/svelte-vite",
  // Expose Rails/Svelte assets to Storybook
  staticDirs: ["../app/frontend/assets"]
};
export default config;
