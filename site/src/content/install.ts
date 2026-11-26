import { intro } from './intro'
import { site } from './site'
import type { Link, Rich } from './types'

type Install = {
  readonly id: string
  readonly heading: string
  readonly body: string
  readonly download: Link
  readonly requirement: string
  readonly brewTitle: string
  readonly brew: string
  readonly footnote: Rich
}

export const install: Install = {
  id: site.links.install.slice(1),
  heading: 'Get Thoughts for your Mac.',
  body: 'Thoughts is free and open source under the MIT License. It checks for updates once a day, and "Update available" appears in the ⋯ menu and the menu bar icon\'s menu when one is ready.',
  download: intro.download,
  requirement: 'Needs macOS 15.4 or later',
  brewTitle: 'Or install it with Homebrew',
  brew: intro.brew,
  footnote: ['The cask also puts the ', { code: 'thoughts' }, ' command line tool on your PATH.'],
}
