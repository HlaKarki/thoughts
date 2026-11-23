import { highlight } from '@/lib/highlight'
import { stamp } from '@/lib/stamp'
import { site } from './site'
import { sourceLine, sources, thoughts, today } from './thoughts'
import type { Rich } from './types'

type Card<Tile> = {
  readonly heading: string
  readonly body: Rich
  readonly tile: Tile
}

type Features = {
  readonly heading: readonly [string, string]
  readonly headingMuted: string
  readonly body: string
  readonly selection: Card<{
    readonly label: string
    readonly key: string
    readonly saved: string
    readonly row: string
    readonly time: string
  }>
  readonly screenshot: Card<{
    readonly label: string
    readonly windowTitle: string
    readonly photo: string
    readonly offerTitle: string
    readonly offerMessage: string
    readonly offerKeys: string
    readonly note: string
    readonly time: string
  }>
  readonly search: Card<{
    readonly label: string
    readonly query: string
    readonly matches: ReadonlyArray<{
      readonly text: Rich
      readonly source: string
      readonly time: string
    }>
    readonly newest: {
      readonly text: string
      readonly time: string
    }
  }>
  readonly markdown: Card<{
    readonly label: string
    readonly fileName: string
    readonly frontMatter: string
    readonly typed: string
    readonly note: string
    readonly time: string
  }>
  readonly agents: Card<{
    readonly label: string
    readonly title: string
    readonly prompt: string
    readonly command: string
    readonly output: string
    readonly row: string
    readonly time: string
  }>
  readonly privacy: Card<{
    readonly label: string
    readonly accessibility: string
    readonly paste: string
    readonly pasteValue: string
    readonly files: string
    readonly app: string
    readonly folder: string
  }>
}

const searchQuery = 'Thursday'
const waldenFile = { id: 'm4q8tz2c', ...stamp(today, thoughts.walden.time, 12) }
const waldenName = `${waldenFile.file}-${waldenFile.id}`

export const features: Features = {
  heading: ['Save it in the app', 'where you found it.'],
  headingMuted: 'Find it later in one list.',
  body: 'Text, todos and screenshots from any app go to one list at the edge of your screen, and each one is a Markdown file. Saved text keeps the app and window it came from, so you can go back to it.',
  selection: {
    heading: 'Press Shift twice to keep a selection',
    body: [
      'Select text in any app and press Shift twice. Thoughts saves it with the app and window it came from, and a note at the edge of the screen shows what it saved.',
    ],
    tile: {
      label: 'A selected sentence on a docs page becomes the newest thought in the panel.',
      key: '⇧',
      saved: 'Saved',
      row: thoughts.clone.text,
      time: thoughts.clone.time,
    },
  },
  screenshot: {
    heading: 'Keep a screenshot with a click',
    body: [
      'Copy an image or take a screenshot, and a small offer slides in at the edge of the screen. Click it or press Shift twice to keep the image as a thought.',
    ],
    tile: {
      label: 'A screenshot of a cat photo becomes a thought with a note in the panel.',
      windowTitle: 'IMG_0412.jpeg',
      photo: site.photos.cat,
      offerTitle: 'Image copied',
      offerMessage: 'Keep as a thought?',
      offerKeys: '⇧⇧',
      note: thoughts.fridge.text,
      time: thoughts.fridge.time,
    },
  },
  search: {
    heading: 'Find any thought by a word in it',
    body: [
      'Press ⌘F in the panel and start typing. The list narrows to the thoughts that match, including the text inside screenshots. Esc clears the search.',
    ],
    tile: {
      label: `A search for ${searchQuery} finds a message from Slack and one from Messages.`,
      query: searchQuery,
      matches: [
        {
          text: highlight(thoughts.review.text, searchQuery),
          source: sourceLine(sources.slack),
          time: thoughts.review.time,
        },
        {
          text: highlight(thoughts.water.text, searchQuery),
          source: sourceLine(sources.messages),
          time: thoughts.water.time,
        },
      ],
      newest: thoughts.table,
    },
  },
  markdown: {
    heading: 'Every thought is a Markdown file',
    body: [
      'Each thought is one Markdown file in a folder you choose, and its front matter records where it came from. Edit the file in any editor and the panel shows the change.',
    ],
    tile: {
      label: 'A line typed into the Markdown file shows up in the panel.',
      fileName: `${waldenName}.md`,
      frontMatter: [
        '---',
        `id: ${waldenFile.id}`,
        `created: ${waldenFile.iso}.408-05:00`,
        'done: null',
        'cleared: false',
        '---',
        thoughts.walden.text,
      ].join('\n'),
      typed: 'I went to the woods because I wished to live deliberately.',
      note: thoughts.walden.text,
      time: thoughts.walden.time,
    },
  },
  agents: {
    heading: 'Your agents can add thoughts too',
    body: [
      'The ',
      { code: 'thoughts' },
      ' command uses the same folder as the app, so a script can run ',
      { code: 'thoughts add' },
      '. Add ',
      { code: 'thoughts mcp' },
      ' to an MCP client and your agent can list, add and search thoughts.',
    ],
    tile: {
      label: 'After an agent reads a report, a command in Terminal adds a thought to the panel.',
      title: 'Terminal',
      prompt: '$ ',
      command: `thoughts add "${thoughts.signups.text}"`,
      output: 'k9w3a7rd',
      row: thoughts.signups.text,
      time: thoughts.signups.time,
    },
  },
  privacy: {
    heading: 'Thoughts asks for Accessibility, paste access and a folder only if needed',
    body: [
      'Accessibility, called Device Control and Data Access on macOS 27, lets Thoughts read what you select and the window title. Paste access lets the offer for a copied image show a preview, and macOS asks for it the first time you keep one. Thoughts asks for your screenshot folder, the Desktop by default, only if macOS guards it. It goes online only to check for updates.',
    ],
    tile: {
      label: 'Thoughts turned on in the Accessibility list (Device Control and Data Access on macOS 27), the Paste from Other Apps list and the Files and Folders list of System Settings.',
      accessibility: 'Accessibility',
      paste: 'Paste from Other Apps',
      pasteValue: 'Always Allow',
      files: 'Files and Folders',
      app: 'Thoughts',
      folder: 'Desktop Folder',
    },
  },
}
