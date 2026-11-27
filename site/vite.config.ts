import { fileURLToPath } from 'node:url'
import { cloudflare } from '@cloudflare/vite-plugin'
import stylex from '@stylexjs/unplugin'
import { tanstackStart } from '@tanstack/react-start/plugin/vite'
import viteReact from '@vitejs/plugin-react'
import { defineConfig, type Plugin } from 'vite'
import { llmsTxt, prerenderPages, sitemapXml } from './src/lib/siteFiles'

const src = fileURLToPath(new URL('./src', import.meta.url))

const siteFiles: Plugin = {
  name: 'site-files',
  apply: 'build',
  applyToEnvironment: (environment) => environment.name === 'client',
  generateBundle() {
    this.emitFile({ type: 'asset', fileName: 'sitemap.xml', source: sitemapXml() })
    this.emitFile({ type: 'asset', fileName: 'llms.txt', source: llmsTxt() })
  },
}

export default defineConfig({
  resolve: {
    alias: { '@': src },
  },
  server: {
    fs: { allow: ['..'] },
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
      pages: prerenderPages,
    }),
    viteReact(),
    siteFiles,
  ],
})
