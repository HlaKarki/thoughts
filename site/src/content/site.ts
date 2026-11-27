import type { ThemedImage } from './types'

const repository = 'https://github.com/HlaKarki/thoughts'

export const site = {
  name: 'Thoughts',
  url: 'https://thoughts.hla.dev',
  language: 'en',
  author: { name: 'Hla Htun', url: 'https://github.com/HlaKarki' },
  operatingSystem: 'macOS 15.4 or later',
  indexNowKey: '2f14e5bf8435adddc64531fc3e3faf77',
  analytics: {
    beacon: 'https://static.cloudflareinsights.com/beacon.min.js',
    token: '68c33c7552a045bb9acd9df16a725a36',
  },
  title: 'Thoughts: a quick scratchpad for your Mac, one key away',
  description:
    'Thoughts is a scratchpad one key away on your Mac. Press ⌥N, jot down what came to mind and get back to work. Each thought is a Markdown file you own.',
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
    tram: '/images/tram.jpg',
    cat: '/images/cat.jpg',
  },
} as const
