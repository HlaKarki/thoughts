import { site } from './site'
import type { Link } from './types'

type Footer = {
  readonly brand: string
  readonly credit: string
  readonly navLabel: string
  readonly links: ReadonlyArray<Link>
}

export const footer: Footer = {
  brand: site.name,
  credit: 'Photos by Jacek Urbanski and Clay Elliot on Unsplash.',
  navLabel: 'Project',
  links: [
    { label: 'Source on GitHub', href: site.links.source },
    { label: 'MIT License', href: site.links.license },
  ],
}
