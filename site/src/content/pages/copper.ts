import { intro } from '../intro'
import { site } from '../site'
import type { Page } from '../types'

export const copper: Page = {
  slug: 'copper-alternative',
  label: 'Coming from Copper',
  group: 'compare',
  navLabel: 'Copper',
  title: 'A free, open source Copper alternative for Mac: Thoughts',
  description:
    'Thoughts works like Copper by shadcn: press Shift twice to keep a selection in a panel one key away. It is free, MIT licensed and keeps every thought as a Markdown file.',
  heading: 'A free, open source Copper alternative for Mac.',
  lead: 'Thoughts works like Copper by shadcn. Select text in any app, press Shift twice, and it lands in a panel one key away. Thoughts is free and MIT licensed, keeps each thought as a Markdown file, and lets your agents read and add thoughts over MCP.',
  sections: [
    {
      heading: 'Thoughts, Copper and Cooper side by side',
      blocks: [
        {
          kind: 'compare',
          caption: 'How Thoughts, Copper and Cooper compare',
          columns: ['Thoughts', 'Copper', 'Cooper'],
          rows: [
            { feature: 'Price', cells: ['Free', '$39, one time', 'Free'] },
            { feature: 'Source', cells: ['Open source, MIT', 'Closed source', 'Open source, Apache 2.0'] },
            { feature: 'Runs on', cells: ['macOS 15.4 or later', 'macOS 14 or later', 'macOS, Windows and Linux'] },
            { feature: 'Keep a selection', cells: ['Press Shift twice', 'Press Shift twice', 'Press Left Shift twice'] },
            {
              feature: 'Where notes live',
              cells: [
                'One Markdown file per thought, in a folder you choose',
                'One local file',
                'One SQLite file, with export to Markdown',
              ],
            },
            {
              feature: 'Images',
              cells: [
                'Offers to keep copied images and new screenshots, and search finds the text inside them',
                'Not mentioned on its site',
                'Drag, drop or paste images',
              ],
            },
            {
              feature: 'Agents',
              cells: [
                'An MCP server and a thoughts command line tool',
                'Not mentioned on its site',
                'Not mentioned in its README',
              ],
            },
            {
              feature: 'Account and sync',
              cells: [
                'No account. Put the folder in iCloud Drive or Dropbox to sync it',
                'No account, no sync',
                'No account, no sync',
              ],
            },
          ],
          note: 'Checked against shadcn.com/copper and the Cooper README on November 27, 2026.',
        },
      ],
    },
    {
      heading: 'What they share',
      blocks: [
        {
          kind: 'text',
          text: [
            'All three keep the small things you find while you work with AI: an answer worth keeping, a link, the next three prompts. All three save a selection when you press Shift twice, keep your notes on your own computer, and need no account. On a Mac, each one asks for Accessibility so it can read what you select.',
          ],
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
        },
      ],
    },
    {
      heading: 'Switching from Copper',
      blocks: [
        {
          kind: 'steps',
          items: [
            ['Install Thoughts with ', { code: intro.brew }, ', or download it from this page.'],
            [
              'Copper and Thoughts both listen for Shift twice. Quit Copper, or record another capture shortcut in Thoughts during first run.',
            ],
            ['Press ⌥N in any app to open the panel, and paste anything you want to bring over.'],
          ],
        },
      ],
    },
  ],
  footnote: `Thoughts is made by Hla Htun and is not affiliated with shadcn or Copper. The source is on GitHub at ${site.links.source.replace('https://', '')}.`,
}
