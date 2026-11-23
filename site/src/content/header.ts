import { site } from './site'
import type { Link } from './types'

type Header = {
  readonly brand: string
  readonly homeLabel: string
  readonly navLabel: string
  readonly nav: ReadonlyArray<Link>
}

export const header: Header = {
  brand: site.name,
  homeLabel: 'Thoughts home',
  navLabel: 'Site',
  nav: [
    { label: 'Install', href: site.links.install },
    { label: 'Source on GitHub', href: site.links.source },
  ],
}
