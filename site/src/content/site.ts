import type { ThemedImage } from './types'

const repository = 'https://github.com/HlaKarki/thoughts'

export const site = {
  name: 'Thoughts',
  url: 'https://thoughts.hla.dev',
  language: 'en',
  title: 'Thoughts, a quiet place for what you find while you work',
  description:
    'Thoughts is a Mac app that keeps text, todos and screenshots from any app as Markdown files. Press ⌥Space to open the panel, or select text and press Shift twice to save it.',
  shareImage: { src: '/share.png', width: 1200, height: 630, alt: 'The Thoughts app icon next to the sentence: Thoughts is a quiet place for what you find while you work.' },
  favicon: { light: '/favicon-light.png', dark: '/favicon-dark.png', apple: '/apple-touch-icon.png' },
  icon: {
    light: '/images/icon-light.png',
    dark: '/images/icon-dark.png',
    alt: 'Thoughts app icon',
  } satisfies ThemedImage,
  links: {
    download: `${repository}/releases/latest/download/Thoughts.zip`,
    source: repository,
    license: `${repository}/blob/HEAD/LICENSE`,
    install: '#install',
  },
  photos: {
    bread: '/images/bread.jpg',
    cat: '/images/cat.jpg',
  },
} as const
