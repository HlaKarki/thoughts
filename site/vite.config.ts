import { fileURLToPath } from 'node:url'
import { cloudflare } from '@cloudflare/vite-plugin'
import stylex from '@stylexjs/unplugin'
import { tanstackStart } from '@tanstack/react-start/plugin/vite'
import viteReact from '@vitejs/plugin-react'
import { defineConfig } from 'vite'

const src = fileURLToPath(new URL('./src', import.meta.url))

export default defineConfig({
  resolve: {
    alias: { '@': src },
  },
  plugins: [
    cloudflare({ viteEnvironment: { name: 'ssr' } }),
    stylex.vite({
      useCSSLayers: true,
      aliases: { '@/*': [`${src}/*`] },
      unstable_moduleResolution: { type: 'commonJS', rootDir: src },
    }),
    tanstackStart({
      router: {
        routesDirectory: 'app',
        generatedRouteTree: 'routeTree.gen.ts',
        virtualRouteConfig: 'src/app/routes.ts',
        routeTreeFileHeader: [],
      },
      prerender: { enabled: true, crawlLinks: false, failOnError: true },
      pages: [{ path: '/' }, { path: '/copper-alternative' }],
    }),
    viteReact(),
  ],
})
