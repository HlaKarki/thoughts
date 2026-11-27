import type { Page } from '../types'

export const appleQuickNote: Page = {
  slug: 'apple-quick-note-alternative',
  label: 'Thoughts and Apple Quick Note',
  group: 'compare',
  navLabel: 'Apple Quick Note',
  title: 'An Apple Quick Note alternative that saves to Markdown: Thoughts',
  description:
    'Thoughts and Apple Quick Note both catch a thought fast on a Mac. Thoughts saves a selection from any app with Shift twice and keeps every note as a Markdown file.',
  heading: 'Thoughts and Apple Quick Note.',
  lead: 'Quick Note is built into every Mac, and it is the fastest way into Apple Notes. Thoughts is for a stream of small things you act on and clear: it saves a selection from any app with one shortcut and keeps each thought as a Markdown file.',
  sections: [
    {
      heading: 'Side by side',
      blocks: [
        {
          kind: 'compare',
          caption: 'How Thoughts and Apple Quick Note compare',
          columns: ['Thoughts', 'Apple Quick Note'],
          rows: [
            { feature: 'Price', cells: ['Free and open source, MIT', 'Built into Notes on your Mac'] },
            { feature: 'Runs on', cells: ['macOS 15.4 or later', 'macOS 12 or later, and iPhone and iPad'] },
            { feature: 'Open it', cells: ['⌥N in any app, or a key you pick', 'Fn or Globe and Q, or the bottom right hot corner'] },
            {
              feature: 'Save a selection',
              cells: [
                'Select text in any app and press Shift twice',
                'In Safari, Control-click and choose Add to Quick Note. In other apps, Share and then Notes',
              ],
            },
            {
              feature: 'Where notes live',
              cells: [
                'One Markdown file per thought, in a folder you choose',
                'In Apple Notes, in iCloud or on your Mac. You can export a note as Markdown or PDF',
              ],
            },
            {
              feature: 'Images',
              cells: [
                'Offers to keep copied images and new screenshots, and search finds the text inside them',
                'Photos, scans, drawings and PDFs. Search finds what an image shows and text in scans',
              ],
            },
            {
              feature: 'Agents and scripts',
              cells: ['An MCP server and a thoughts command line tool', 'Shortcuts actions to create and append notes'],
            },
            { feature: 'Sync', cells: ['Put the folder in iCloud Drive or Dropbox', 'iCloud or another mail account'] },
          ],
          note: "Checked against Apple's Notes User Guide on November 27, 2026.",
        },
      ],
    },
    {
      blocks: [
        {
          kind: 'picks',
          picks: [
            {
              heading: 'Pick Thoughts if',
              reasons: [
                'You save selections from many apps and want one shortcut that works in all of them.',
                'You want plain Markdown files that any editor, script or agent can open.',
                'You keep todos and prompts you check off and clear.',
              ],
            },
            {
              heading: 'Pick Quick Note if',
              reasons: [
                'You already keep everything in Apple Notes.',
                'You want your notes on your iPhone and iPad too.',
                'You want rich notes with drawings, scans and tables.',
              ],
            },
          ],
        },
      ],
    },
    {
      heading: 'Using both',
      blocks: [
        {
          kind: 'text',
          text: [
            'They work well together. Use Thoughts for the quick, short-lived things, and copy a thought into Notes with ⌘C when it deserves a real note.',
          ],
        },
      ],
    },
  ],
}
