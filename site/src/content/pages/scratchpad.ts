import type { Page } from '../types'

export const scratchpad: Page = {
  slug: 'mac-scratchpad',
  label: 'A scratchpad for your Mac',
  title: 'A quick scratchpad for Mac that opens with one key: Thoughts',
  description:
    'Press ⌥N in any app to open a scratchpad, jot down what came to mind and get back to work. Thoughts is free, and every note is a Markdown file you own.',
  heading: 'A scratchpad for your Mac, one key away.',
  lead: 'Something comes to mind in the middle of other work: a todo, a prompt to try next, a name to look up. Press ⌥N, type it, press Return, and you are back where you were.',
  sections: [
    {
      heading: 'Made for the thing you would otherwise lose',
      blocks: [
        {
          kind: 'text',
          text: [
            'The panel opens over the app you are in and takes one line. There is nothing to name or file. Click outside the panel or press Esc and it hides again, so the thought costs you a few seconds and nothing else.',
          ],
        },
      ],
    },
    {
      heading: 'Save from any app',
      blocks: [
        {
          kind: 'text',
          text: [
            'Select text anywhere and press Shift twice to save it with the app and window it came from. Copy an image or take a screenshot, and Thoughts offers to keep that too. See ',
            { link: { label: 'saving selected text', href: '/save-selected-text-mac' } },
            ' and ',
            { link: { label: 'keeping screenshots', href: '/screenshots-to-markdown' } },
            '.',
          ],
        },
      ],
    },
    {
      heading: 'Check things off as you go',
      blocks: [
        {
          kind: 'list',
          items: [
            ['⌘Return marks a thought done, and Clear done in the ⋯ menu hides the finished ones.'],
            ['⌘Z undoes a delete, a Clear done or an edit.'],
            ['⌘C copies a thought, ready to paste into a prompt or a message.'],
          ],
        },
      ],
    },
    {
      heading: 'Find it again',
      blocks: [
        {
          kind: 'text',
          text: [
            'Press ⌘F and the list narrows as you type, including the text inside screenshots. ⌘O opens the page or app a thought came from.',
          ],
        },
      ],
    },
    {
      heading: 'Plain files you own',
      blocks: [
        {
          kind: 'text',
          text: [
            'Every thought is a Markdown file in a folder you choose. Open it in any editor, sync it with iCloud Drive or Dropbox, or let ',
            { link: { label: 'your AI agents', href: '/mcp' } },
            ' read and add to it.',
          ],
        },
      ],
    },
  ],
}
