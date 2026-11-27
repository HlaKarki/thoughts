import { site } from '@/content/site'

type Page = {
  readonly path: string
  readonly title: string
  readonly description: string
}

export function pageUrl(path: string) {
  return path === '/' ? site.url : `${site.url}${path}`
}

export function pageHead({ path, title, description }: Page) {
  const url = pageUrl(path)
  return {
    meta: [
      { title },
      { name: 'description', content: description },
      { property: 'og:url', content: url },
      { property: 'og:title', content: title },
      { property: 'og:description', content: description },
    ],
    links: [{ rel: 'canonical', href: url }],
  }
}
