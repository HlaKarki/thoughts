import type { Page } from '../types'

export const screenshots: Page = {
  slug: 'screenshots-to-markdown',
  label: 'Keep screenshots as notes',
  title: 'Save screenshots and copied images as Markdown notes on Mac: Thoughts',
  description:
    'Take a screenshot or copy an image, and Thoughts offers to keep it. Each image is saved as a PNG beside a Markdown note, and search finds the text inside it.',
  heading: 'Keep screenshots as notes you can search.',
  lead: 'Take a screenshot or copy an image, and a small offer slides in at the edge of the screen. Click it, or press Shift twice, and the image becomes a thought you can add a note to.',
  sections: [
    {
      heading: 'Which images Thoughts offers',
      blocks: [
        {
          kind: 'list',
          items: [
            ['An image you copy in any app.'],
            ['A new screenshot in your screenshot folder, which is the Desktop unless you changed it.'],
            ['New images in any other folder you add in Settings.'],
          ],
        },
        {
          kind: 'text',
          text: [
            'When a tool both copies and saves the same screenshot, you get one offer. You can also drop images on the panel.',
          ],
        },
      ],
    },
    {
      heading: 'Search the text inside',
      blocks: [
        {
          kind: 'text',
          text: [
            'Thoughts reads the text in each screenshot on your Mac, so ⌘F finds a screenshot by the words in it. The ',
            { code: 'thoughts search' },
            ' command finds them too.',
          ],
        },
      ],
    },
    {
      heading: 'Files you can open anywhere',
      blocks: [
        {
          kind: 'text',
          text: [
            'Each screenshot is a PNG with the same name as its Markdown file, side by side in your thoughts folder. The note you add is the body of the Markdown file, and the front matter names the image.',
          ],
        },
        {
          kind: 'code',
          label: '20261122-181403-ke6s0pcg.md',
          code: `---
id: ke6s0pcg
created: 2026-11-22T18:14:03.120-05:00
done: null
cleared: false
image: 20261122-181403-ke6s0pcg.png
---
The building notice about the water shut off`,
        },
      ],
    },
    {
      heading: 'Copy it back out',
      blocks: [
        {
          kind: 'text',
          text: [
            'Select a screenshot thought and press Space to preview it, ⌘C to copy the image, or ⇧⌘C to copy its path for a script or ',
            { link: { label: 'an AI agent', href: '/mcp' } },
            '.',
          ],
        },
      ],
    },
  ],
}
