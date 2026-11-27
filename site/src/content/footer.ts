import { pages } from './pages'
import { site } from './site'
import type { Link, PageGroup } from './types'

type Column = {
  readonly heading: string
  readonly links: ReadonlyArray<Link>
}

type Footer = {
  readonly brand: string
  readonly tagline: string
  readonly maker: { readonly before: string; readonly link: Link }
  readonly credit: string
  readonly navLabel: string
  readonly columns: ReadonlyArray<Column>
}

function pageLinks(group: PageGroup) {
  return pages.filter((page) => page.group === group).map((page) => ({ label: page.navLabel, href: `/${page.slug}` }))
}

export const footer: Footer = {
  brand: site.name,
  tagline: 'A scratchpad one key away on your Mac. Free and open source.',
  maker: { before: 'Made by ', link: { label: site.author.name, href: site.author.url } },
  credit: 'Photos by Jacek Urbanski and Clay Elliot on Unsplash.',
  navLabel: 'More about Thoughts',
  columns: [
    { heading: 'Use Thoughts', links: pageLinks('guides') },
    { heading: 'Compare', links: pageLinks('compare') },
    {
      heading: 'Project',
      links: [
        ...pageLinks('project'),
        { label: 'Source on GitHub', href: site.links.source },
        { label: 'MIT License', href: site.links.license },
      ],
    },
  ],
}
