import { defineConfig } from 'vitest/config';
import { svelte } from '@sveltejs/vite-plugin-svelte';
import path from 'node:path';

export default defineConfig({
  plugins: [svelte({ configFile: path.join(__dirname, 'svelte.config.js') })],
  resolve: {
    alias: {
      '@': path.resolve(__dirname, 'app/frontend'),
      '/components': path.resolve(__dirname, 'app/frontend/components'),
      '/assets': path.resolve(__dirname, 'app/frontend/assets'),
      '/lib': path.resolve(__dirname, 'app/frontend/lib'),
      '/routes': path.resolve(__dirname, 'app/frontend/routes'),
    },
    // Ensure Vitest resolves browser entry points when running tests
    conditions: ['browser']
  },
  test: {
    globals: true,
    exclude: ['**/stories/**', '**/node_modules/**'],
    environment: 'jsdom',
    setupFiles: ['spec/setupTests.ts'],
    testTimeout: 60000,
    hookTimeout: 60000,
    fileParallelism: false
  },
});
