import * as stylex from '@stylexjs/stylex'
import { HeadContent, Outlet, Scripts, createRootRoute } from '@tanstack/react-router'
import type { ReactNode } from 'react'
import { site } from '@/content/site'
import { NotFound } from './NotFound'
import globalCss from '@/styles/global.css?url'
import { color, font } from '@/styles/tokens.stylex'

const shareImage = `${site.url}${site.shareImage.src}`

export const Route = createRootRoute({
  head: () => ({
    meta: [
      { charSet: 'utf-8' },
      { name: 'viewport', content: 'width=device-width, initial-scale=1' },
      { title: site.title },
      { name: 'description', content: site.description },
      { name: 'color-scheme', content: 'light dark' },
      { property: 'og:type', content: 'website' },
      { property: 'og:url', content: site.url },
      { property: 'og:title', content: site.title },
      { property: 'og:description', content: site.description },
      { property: 'og:image', content: shareImage },
      { property: 'og:image:width', content: String(site.shareImage.width) },
      { property: 'og:image:height', content: String(site.shareImage.height) },
      { property: 'og:image:alt', content: site.shareImage.alt },
      { name: 'twitter:card', content: 'summary_large_image' },
      { name: 'twitter:image', content: shareImage },
    ],
    links: [
      { rel: 'stylesheet', href: globalCss },
      ...(import.meta.env.DEV ? [{ rel: 'stylesheet', href: '/virtual:stylex.css' }] : []),
      { rel: 'canonical', href: site.url },
      { rel: 'icon', type: 'image/png', href: site.favicon.light, media: '(prefers-color-scheme: light)' },
      { rel: 'icon', type: 'image/png', href: site.favicon.dark, media: '(prefers-color-scheme: dark)' },
      { rel: 'apple-touch-icon', href: site.favicon.apple },
    ],
    scripts: import.meta.env.DEV
      ? [{ type: 'module', children: "import('/@id/virtual:stylex:runtime')" }]
      : [],
  }),
  component: RootDocument,
  notFoundComponent: NotFound,
})

function RootDocument() {
  return (
    <Document>
      <Outlet />
    </Document>
  )
}

function Document({ children }: { readonly children: ReactNode }) {
  return (
    <html lang={site.language}>
      <head>
        <HeadContent />
      </head>
      <body {...stylex.props(styles.body)}>
        {children}
        <Scripts />
      </body>
    </html>
  )
}

const styles = stylex.create({
  body: {
    backgroundColor: color.pageBg,
    color: color.text,
    fontFamily: font.text,
    WebkitFontSmoothing: 'antialiased',
    MozOsxFontSmoothing: 'grayscale',
    fontSynthesis: 'none',
    overflowX: 'clip',
  },
})
