import type { Page } from '../types'

export const selectedText: Page = {
  slug: 'save-selected-text-mac',
  label: 'Save selected text from any app',
  group: 'guides',
  navLabel: 'Save selected text',
  title: 'Save selected text from any Mac app with one shortcut: Thoughts',
  description:
    'Select text in any Mac app and press Shift twice. Thoughts saves it as a Markdown note with the app, window and web page it came from.',
  heading: 'Save selected text from any app with one shortcut.',
  lead: 'Select text in Safari, Slack, a PDF or your editor and press Shift twice. Thoughts saves it with the app and window it came from, and a note at the edge of the screen shows what it saved.',
  sections: [
    {
      heading: 'How it works',
      blocks: [
        {
          kind: 'steps',
          items: [
            ['Select text in any app.'],
            ['Press Shift twice, or the shortcut you recorded in its place.'],
            ['A note at the edge of the screen shows what Thoughts saved, and you keep working.'],
          ],
        },
        {
          kind: 'text',
          text: [
            'If nothing is selected, Shift twice saves what you copied in the last 2 minutes. It skips copies from password managers.',
          ],
        },
      ],
    },
    {
      heading: 'It remembers where it came from',
      blocks: [
        {
          kind: 'text',
          text: [
            'Each saved selection keeps the app and the window title, and the page address when it comes from a browser. Select the thought and press ⌘O to go back to the page or app.',
          ],
        },
      ],
    },
    {
      heading: 'What macOS asks you to allow',
      blocks: [
        {
          kind: 'list',
          items: [
            [
              'Accessibility, so Thoughts can read what you select and the window title. macOS 27 calls it Device Control and Data Access.',
            ],
            ['Paste from other apps, so Shift twice can save what you copied.'],
          ],
        },
        {
          kind: 'text',
          text: [
            'Thoughts never asks for Input Monitoring. More in the ',
            { link: { label: 'questions and answers', href: '/faq' } },
            '.',
          ],
        },
      ],
    },
    {
      heading: 'Also in the Share menu',
      blocks: [
        {
          kind: 'text',
          text: [
            'In apps with a Share menu, choose Add to Thoughts. You can also drop text, images or files on the panel.',
          ],
        },
      ],
    },
  ],
}
