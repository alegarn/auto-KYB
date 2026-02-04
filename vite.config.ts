/// <reference types="vitest/config" />
import tailwindcss from '@tailwindcss/vite';
import { svelte } from '@sveltejs/vite-plugin-svelte';
import { defineConfig } from 'vitest/config';
import RubyPlugin from 'vite-plugin-ruby';
import { fileURLToPath } from 'url';
import path from 'node:path';
import { storybookTest } from '@storybook/addon-vitest/vitest-plugin';
import { playwright } from '@vitest/browser-playwright';

const dirname = typeof __dirname !== 'undefined' ? __dirname : path.dirname(fileURLToPath(import.meta.url));

// More info at: https://storybook.js.org/docs/next/writing-tests/integrations/vitest-addon
export default defineConfig({
  plugins: [
    tailwindcss(),
    // Explicitly point the Svelte plugin at the project's Svelte config so it can be
    // resolved when running inside Storybook / Vitest.
    svelte({ configFile: path.join(dirname, 'svelte.config.js') }),
    RubyPlugin()
  ],
  // Ensure Vitest resolves browser entry points when running inside Vitest
  resolve: process.env.VITEST ? {
    conditions: ['browser']
  } : undefined,
  test: {
    // Two distinct Vitest projects:
    // 1) storybook - runs Storybook browser-mode tests using the Storybook addon
    // 2) component-tests - runs standalone component/unit tests located under test/frontend/component_tests
    projects: [
      {
        extends: true,
        plugins: [
          storybookTest({
            configDir: path.join(dirname, '.storybook')
          })
        ],
        test: {
          name: 'storybook',
          // Run from repository root so story globs in .storybook/main.ts and stories/ are discoverable
          root: dirname,
          browser: {
            enabled: true,
            headless: true,
            provider: playwright({}),
            instances: [{ browser: 'chromium' }]
          },
          setupFiles: ['.storybook/vitest.setup.ts']
        }
      },
      {
        extends: true,
        test: {
          name: 'component-tests',
          root: dirname,
          // Include our dedicated component test folder
          include: ['test/frontend/component_tests/**/*.spec.@(js|ts|svelte)']
        }
      }
    ]
  }
});
