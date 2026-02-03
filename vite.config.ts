import tailwindcss from '@tailwindcss/vite'
import { svelte } from '@sveltejs/vite-plugin-svelte'
import { defineConfig } from 'vitest/config'
import RubyPlugin from 'vite-plugin-ruby'
import { fileURLToPath } from 'url'
import { dirname, resolve } from 'path'

export default defineConfig({
  plugins: [
    tailwindcss(),
    svelte(),
    RubyPlugin(),
  ],
  // Ensure Vitest resolves browser entry points when running inside Vitest
  resolve: process.env.VITEST
    ? {
        conditions: ['browser']
      }
    : undefined,
  test: (() => {
    // Resolve paths relative to repository root so Vitest can find spec/frontend
    const __dirname = dirname(fileURLToPath(import.meta.url))
    const repoRoot = resolve(__dirname)
    return {
      environment: 'jsdom',
      include: [resolve(repoRoot, 'spec/frontend') + '/**/*.spec.ts'],
      setupFiles: resolve(repoRoot, 'spec/frontend/setupTests.ts')
    }
  })()
})
