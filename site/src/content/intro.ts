import { site } from './site'
import type { Link } from './types'

type Intro = {
  readonly title: string
  readonly lead: string
  readonly download: Link
}

export const intro: Intro = {
  title: 'Thoughts is a quiet place for what you find while you work.',
  lead: 'Press ⌥N in any app to open the panel, or select text and press Shift twice to save it.',
  download: { label: 'Download for Mac', href: site.links.download },
}
