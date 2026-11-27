import type { Page } from '../types'

export const drafts: Page = {
  slug: 'drafts-alternative',
  label: 'Thoughts and Drafts',
  title: 'A free Drafts alternative for Mac with Markdown files: Thoughts',
  description:
    'Thoughts and Drafts both catch text quickly on a Mac. Thoughts is free and open source, saves a selection with Shift twice, keeps screenshots and stores Markdown files.',
  heading: 'Thoughts and Drafts.',
  lead: 'Drafts is a deep text capture app with actions for nearly anything you write. Thoughts does less on purpose: it keeps small things you find while you work, from text to screenshots, one key away and as plain Markdown files.',
  sections: [
    {
      heading: 'Side by side',
      blocks: [
        {
          kind: 'compare',
          caption: 'How Thoughts and Drafts compare',
          columns: ['Thoughts', 'Drafts'],
          rows: [
            {
              feature: 'Price',
              cells: ['Free and open source, MIT', 'Free. Pro is $2.99 a month or $24.99 a year'],
            },
            {
              feature: 'Runs on',
              cells: ['macOS 15.4 or later', 'macOS 12.7 or later, plus iPhone, iPad and Apple Watch'],
            },
            {
              feature: 'Open it',
              cells: ['⌥N in any app, or a key you pick', 'A capture window on ⇧⌘2, or the menu bar'],
            },
            {
              feature: 'Save a selection',
              cells: ['Select text in any app and press Shift twice', 'Capture to Drafts in the Services menu'],
            },
            {
              feature: 'Where notes live',
              cells: [
                'One Markdown file per thought, in a folder you choose',
                'In iCloud, outside iCloud Drive. Backups are JSON',
              ],
            },
            {
              feature: 'Images',
              cells: [
                'Keeps copied images and new screenshots, and search finds the text inside them',
                'Turns the text in an image into a new draft',
              ],
            },
            {
              feature: 'Automation',
              cells: [
                'An MCP server and a thoughts command line tool',
                'Actions, a URL scheme, AppleScript, Shortcuts, an MCP server and a drafts command line tool',
              ],
            },
          ],
          note: "Checked against Drafts' site, docs and App Store listing on November 27, 2026.",
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
                'You want your notes as Markdown files in a folder, ready for any editor or agent.',
                'You keep screenshots and copied images next to your text.',
                'You want a free, open source app that does one thing.',
              ],
            },
            {
              heading: 'Pick Drafts if',
              reasons: [
                'You write on iPhone, iPad and Apple Watch as well as your Mac.',
                'You want actions that send text to other apps and services.',
                'Your Mac runs a version of macOS older than 15.4.',
              ],
            },
          ],
        },
      ],
    },
  ],
}
