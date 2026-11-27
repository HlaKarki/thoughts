import { site } from './site'
import type { Link } from './types'

type Intro = {
  readonly title: string
  readonly lead: string
  readonly download: Link
  readonly brew: string
  readonly send: {
    readonly label: string
    readonly note: string
    readonly copied: string
  }
}

export const intro: Intro = {
  title: 'Thoughts is a quiet place for what you find while you work.',
  lead: 'A scratchpad one key away on your Mac. Press ⌥N to catch a thought before it slips away, or select text and press Shift twice to keep it.',
  download: { label: 'Download for Mac', href: site.links.download },
  brew: 'brew install --cask hlakarki/tap/thoughts',
  send: {
    label: 'Send to my Mac',
    note: 'Thoughts is a Mac app. Needs macOS 15.4 or later.',
    copied: 'Link copied',
  },
}
