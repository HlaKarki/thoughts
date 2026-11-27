import type { Page } from '../types'

export const raycastNotes: Page = {
  slug: 'raycast-notes-alternative',
  label: 'Thoughts and Raycast Notes',
  title: 'A Raycast Notes alternative with Markdown files: Thoughts',
  description:
    'Thoughts and Raycast Notes both open a note window with one key. Thoughts saves a selection from any app with Shift twice and keeps each thought as a Markdown file.',
  heading: 'Thoughts and Raycast Notes.',
  lead: 'Raycast Notes is a floating notes window inside Raycast. Thoughts is a list of small things you keep and clear: it saves a selection from any app with one shortcut, keeps screenshots, and saves each thought as a Markdown file.',
  sections: [
    {
      heading: 'Side by side',
      blocks: [
        {
          kind: 'compare',
          caption: 'How Thoughts and Raycast Notes compare',
          columns: ['Thoughts', 'Raycast Notes'],
          rows: [
            { feature: 'Price', cells: ['Free and open source, MIT', 'Free. Sync needs a paid Raycast plan'] },
            {
              feature: 'Runs on',
              cells: ['macOS 15.4 or later', 'macOS Tahoe on Apple Silicon, plus Windows and iPhone'],
            },
            { feature: 'Open it', cells: ['⌥N in any app, or a key you pick', 'A hotkey you assign, or the menu bar'] },
            {
              feature: 'Save a selection',
              cells: [
                'Select text in any app and press Shift twice',
                'Build a Quicklink with the selection placeholder',
              ],
            },
            {
              feature: 'Where notes live',
              cells: [
                'One Markdown file per thought, in a folder you choose',
                'An encrypted database, with export to Markdown, plain text or HTML',
              ],
            },
            {
              feature: 'Images',
              cells: [
                'Offers to keep copied images and new screenshots, and search finds the text inside them',
                'Paste or drop images into a note',
              ],
            },
            {
              feature: 'Agents',
              cells: [
                'An MCP server and a thoughts command line tool, free',
                "Raycast's MCP server, on a paid plan",
              ],
            },
            {
              feature: 'One note or many',
              cells: ['A list of thoughts you check off and clear', 'Many notes, one shown at a time'],
            },
          ],
          note: "Checked against Raycast's site and manual on November 27, 2026.",
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
                'You want Shift twice to save a selection from any app, with nothing to set up.',
                'You want plain files you can open, sync and script without a paid plan.',
                'You keep screenshots and want to search the text inside them.',
              ],
            },
            {
              heading: 'Pick Raycast Notes if',
              reasons: [
                'You already live in Raycast and want notes next to your other commands.',
                'You write longer notes with formatting, one at a time.',
                'You want your notes on Windows or iPhone too.',
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
            'Many people give Raycast Notes the ⌥N hotkey, which is also the key Thoughts opens with. If you use both, change one of them: Thoughts lets you record another key during first run or in Settings.',
          ],
        },
      ],
    },
  ],
}
