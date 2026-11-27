import { intro } from './intro'
import { site } from './site'
import type { Link, Rich } from './types'

export type Comparison = {
  readonly feature: string
  readonly thoughts: string
  readonly copper: string
  readonly cooper: string
}

export type Pick = {
  readonly heading: string
  readonly reasons: ReadonlyArray<string>
}

type Copper = {
  readonly path: string
  readonly title: string
  readonly description: string
  readonly heading: string
  readonly lead: string
  readonly download: Link
  readonly brew: string
  readonly table: {
    readonly heading: string
    readonly caption: string
    readonly columns: readonly [string, string, string, string]
    readonly rows: ReadonlyArray<Comparison>
    readonly checked: string
  }
  readonly same: {
    readonly heading: string
    readonly body: string
  }
  readonly picks: ReadonlyArray<Pick>
  readonly switching: {
    readonly heading: string
    readonly steps: ReadonlyArray<Rich>
  }
  readonly affiliation: string
}

export const copper: Copper = {
  path: '/copper-alternative',
  title: 'A free, open source Copper alternative for Mac: Thoughts',
  description:
    'Thoughts works like Copper by shadcn: press Shift twice to keep a selection in a panel one key away. It is free, MIT licensed and keeps every thought as a Markdown file.',
  heading: 'A free, open source Copper alternative for Mac.',
  lead: 'Thoughts works like Copper by shadcn. Select text in any app, press Shift twice, and it lands in a panel one key away. Thoughts is free and MIT licensed, keeps each thought as a Markdown file, and lets your agents read and add thoughts over MCP.',
  download: intro.download,
  brew: intro.brew,
  table: {
    heading: 'Thoughts, Copper and Cooper side by side',
    caption: 'How Thoughts, Copper and Cooper compare',
    columns: ['', 'Thoughts', 'Copper', 'Cooper'],
    rows: [
      { feature: 'Price', thoughts: 'Free', copper: '$39, one time', cooper: 'Free' },
      {
        feature: 'Source',
        thoughts: 'Open source, MIT',
        copper: 'Closed source',
        cooper: 'Open source, Apache 2.0',
      },
      {
        feature: 'Runs on',
        thoughts: 'macOS 15.4 or later',
        copper: 'macOS 14 or later',
        cooper: 'macOS, Windows and Linux',
      },
      {
        feature: 'Keep a selection',
        thoughts: 'Press Shift twice',
        copper: 'Press Shift twice',
        cooper: 'Press Left Shift twice',
      },
      {
        feature: 'Where notes live',
        thoughts: 'One Markdown file per thought, in a folder you choose',
        copper: 'One local file',
        cooper: 'One SQLite file, with export to Markdown',
      },
      {
        feature: 'Images',
        thoughts: 'Offers to keep copied images and new screenshots, and search finds the text inside them',
        copper: 'Not mentioned on its site',
        cooper: 'Drag, drop or paste images',
      },
      {
        feature: 'Agents',
        thoughts: 'An MCP server and a thoughts command line tool',
        copper: 'Not mentioned on its site',
        cooper: 'Not mentioned in its README',
      },
      {
        feature: 'Account and sync',
        thoughts: 'No account. Put the folder in iCloud Drive or Dropbox to sync it',
        copper: 'No account, no sync',
        cooper: 'No account, no sync',
      },
    ],
    checked: 'Checked against shadcn.com/copper and the Cooper README on November 27, 2026.',
  },
  same: {
    heading: 'What they share',
    body: 'All three keep the small things you find while you work with AI: an answer worth keeping, a link, the next three prompts. All three save a selection when you press Shift twice, keep your notes on your own computer, and need no account. On a Mac, each one asks for Accessibility so it can read what you select.',
  },
  picks: [
    {
      heading: 'Pick Thoughts if',
      reasons: [
        'You want plain Markdown files that any editor, script or agent can open.',
        'You save screenshots and copied images, and want search to find the text inside them.',
        'You want your agents to add and search thoughts over MCP.',
      ],
    },
    {
      heading: 'Pick Copper if',
      reasons: [
        'You want the original app from shadcn and are happy to pay $39 for it.',
        'Your Mac runs macOS 14, which Thoughts does not support.',
      ],
    },
    {
      heading: 'Pick Cooper if',
      reasons: [
        'You work on Windows or Linux, where Thoughts and Copper do not run.',
        'You want sections, color tags and a drawing pad.',
      ],
    },
  ],
  switching: {
    heading: 'Switching from Copper',
    steps: [
      ['Install Thoughts with ', { code: intro.brew }, ', or download it from this page.'],
      [
        'Copper and Thoughts both listen for Shift twice. Quit Copper, or record another capture shortcut in Thoughts during first run.',
      ],
      ['Press ⌥N in any app to open the panel, and paste anything you want to bring over.'],
    ],
  },
  affiliation: `Thoughts is made by Hla Htun and is not affiliated with shadcn or Copper. The source is on GitHub at ${site.links.source.replace('https://', '')}.`,
}
