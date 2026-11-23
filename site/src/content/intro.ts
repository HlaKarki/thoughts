import { site } from './site'
import type { Link } from './types'

type Intro = {
  readonly title: string
  readonly titleMuted: string
  readonly lead: string
  readonly download: Link
  readonly brew: string
  readonly brewLabel: string
  readonly requirements: string
}

export const intro: Intro = {
  title: 'Thoughts is a quiet place for what you find while you work.',
  titleMuted: 'It keeps text, todos and screenshots from any app as Markdown files.',
  lead: 'Press ⌥Space in any app to open the panel. Type a thought and press Return, or select text anywhere and press Shift twice to save it. Thoughts runs with no Dock icon and waits until you call it.',
  download: { label: 'Download for Mac', href: site.links.download },
  brew: 'brew install --cask hlakarki/tap/thoughts',
  brewLabel: 'Homebrew command',
  requirements: 'Thoughts needs macOS 15.4 or later. It is open source under the MIT License.',
}
