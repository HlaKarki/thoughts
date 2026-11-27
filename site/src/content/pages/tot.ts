import type { Page } from '../types'

export const tot: Page = {
  slug: 'tot-alternative',
  label: 'Thoughts and Tot',
  title: 'A Tot alternative for Mac with no note limit: Thoughts',
  description:
    'Thoughts and Tot both keep a scratchpad one key away on a Mac. Thoughts has no limit on notes, saves a selection with Shift twice, keeps screenshots and stores Markdown files.',
  heading: 'Thoughts and Tot.',
  lead: 'Tot gives you seven dots of text, one key away. Thoughts keeps a list with no limit: every thought, selection and screenshot you save becomes its own Markdown file, and you check them off as you go.',
  sections: [
    {
      heading: 'Side by side',
      blocks: [
        {
          kind: 'compare',
          caption: 'How Thoughts and Tot compare',
          columns: ['Thoughts', 'Tot'],
          rows: [
            {
              feature: 'Price',
              cells: ['Free and open source, MIT', 'Free, with a $19.99 Mac upgrade for more features'],
            },
            {
              feature: 'Runs on',
              cells: ['macOS 15.4 or later', 'macOS 14 or later, plus iPhone, iPad and Apple Watch'],
            },
            { feature: 'Open it', cells: ['⌥N in any app, or a key you pick', 'A hotkey you record, or the menu bar'] },
            {
              feature: 'How much it holds',
              cells: ['As many thoughts as you save', 'Seven dots, up to 100,000 characters each'],
            },
            {
              feature: 'Save a selection',
              cells: ['Select text in any app and press Shift twice', 'Not mentioned on its site'],
            },
            {
              feature: 'Where notes live',
              cells: ['One Markdown file per thought, in a folder you choose', 'iCloud, with hourly JSON backups'],
            },
            {
              feature: 'Images',
              cells: [
                'Keeps copied images and new screenshots, and search finds the text inside them',
                'Not mentioned on its site',
              ],
            },
            {
              feature: 'Search',
              cells: ['Every thought, including text in screenshots', 'Within the dot you have open'],
            },
          ],
          note: "Checked against Tot's site, help articles and App Store listing on November 27, 2026.",
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
                'Seven notes are not enough, or you want each thing kept on its own.',
                'You want to save selections and screenshots from any app.',
                'You want plain files you can sync, script and hand to an agent.',
              ],
            },
            {
              heading: 'Pick Tot if',
              reasons: [
                'You like a small, fixed set of pages that never grows.',
                'You want the same text on your iPhone, iPad and Apple Watch.',
                'Your Mac runs macOS 14.',
              ],
            },
          ],
        },
      ],
    },
  ],
}
