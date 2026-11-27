import { intro } from '../intro'
import { site } from '../site'
import type { Page } from '../types'

export const faq: Page = {
  slug: 'faq',
  label: 'Questions and answers',
  group: 'guides',
  navLabel: 'Questions',
  title: 'Thoughts FAQ: files, permissions, shortcuts and privacy',
  description:
    'Answers about Thoughts, the Mac scratchpad: where your thoughts are saved, what macOS asks you to allow, the keyboard shortcuts, sync, updates and privacy.',
  heading: 'Questions about Thoughts.',
  lead: 'Where your thoughts are saved, what macOS asks you to allow, and how Thoughts fits into the rest of your Mac.',
  sections: [
    {
      blocks: [
        {
          kind: 'questions',
          items: [
            {
              question: 'What is Thoughts?',
              answer: [
                'A scratchpad one key away on your Mac. Press ⌥N in any app to open the panel and jot something down, or select text and press Shift twice to save it. Every thought is a Markdown file in a folder you choose.',
              ],
            },
            {
              question: 'Is Thoughts free?',
              answer: [
                'Yes. Thoughts is free and open source under the MIT License, and the source is on ',
                { link: { label: 'GitHub', href: site.links.source } },
                '.',
              ],
            },
            {
              question: 'Which Macs does it run on?',
              answer: ['Any Mac with macOS 15.4 or later.'],
            },
            {
              question: 'How do I install it?',
              answer: [
                'Download it from the home page, or run ',
                { code: intro.brew },
                '. The Homebrew cask also puts the ',
                { code: 'thoughts' },
                ' command line tool on your PATH.',
              ],
            },
            {
              question: 'Where are my thoughts saved?',
              answer: [
                'In ',
                { code: '~/Thoughts' },
                ' unless you pick another folder. Each thought is one Markdown file, and a screenshot is a PNG next to its Markdown file. To move the folder, change it in Settings. Thoughts moves the files and leaves a link at the old path.',
              ],
            },
            {
              question: 'Can I edit the files myself?',
              answer: [
                'Yes. Edit a file in any editor and the panel shows the change. Thoughts keeps any front matter keys it does not know.',
              ],
            },
            {
              question: 'How do I open Thoughts?',
              answer: [
                'Press ⌥N in any app to show or hide the panel. You can change the key in Settings, or choose Show Thoughts from the Thoughts icon in the menu bar.',
              ],
            },
            {
              question: 'How do I save text from another app?',
              answer: [
                'Select it and press Shift twice. If nothing is selected, Shift twice saves what you copied in the last 2 minutes. You can record your own shortcut in place of Shift twice. See ',
                { link: { label: 'saving selected text', href: '/save-selected-text-mac' } },
                '.',
              ],
            },
            {
              question: 'Can I keep screenshots and images?',
              answer: [
                'Yes. When you copy an image or take a screenshot, a small offer slides in at the edge of the screen. Click it to keep the image. Search finds the text inside screenshots too. See ',
                { link: { label: 'keeping screenshots', href: '/screenshots-to-markdown' } },
                '.',
              ],
            },
            {
              question: 'Why does Thoughts ask for Accessibility?',
              answer: [
                'So it can read the text you select and the title of the window you are in, which is how each thought records where it came from. macOS 27 calls this permission Device Control and Data Access. Thoughts never asks for Input Monitoring.',
              ],
            },
            {
              question: 'Why does macOS ask about pasting from other apps?',
              answer: [
                'Thoughts reads what you copy, so Shift twice can save a copy and an offer can show a preview of an image. Choose Allow Paste. You can change it later in System Settings under Privacy & Security, Paste from Other Apps.',
              ],
            },
            {
              question: 'Does Thoughts sync between Macs?',
              answer: [
                'Thoughts has no account and no sync service of its own. Put your thoughts folder in iCloud Drive or Dropbox, and it syncs to your other Macs.',
              ],
            },
            {
              question: 'Does Thoughts collect any data?',
              answer: [
                'No. The only network request Thoughts makes is a daily check for updates, and it sends nothing you saved.',
              ],
            },
            {
              question: 'How do updates work?',
              answer: [
                'Thoughts checks for updates once a day. When one is ready, "Update available" appears in the ⋯ menu and in the menu bar icon\'s menu. You can also choose "Check for updates…" in either menu.',
              ],
            },
            {
              question: 'Can my AI agents use Thoughts?',
              answer: [
                'Yes. Thoughts has an MCP server and a command line tool, so agents like Claude Code and Cursor can add, search and check off thoughts. See ',
                { link: { label: 'Thoughts for AI agents', href: '/mcp' } },
                '.',
              ],
            },
            {
              question: 'How is Thoughts different from Copper?',
              answer: [
                'Both save a selection when you press Shift twice. Thoughts is free and open source, keeps each thought as a Markdown file, keeps screenshots, and has an MCP server. See the ',
                { link: { label: 'comparison', href: '/copper-alternative' } },
                '.',
              ],
            },
            {
              question: 'How do I uninstall it?',
              answer: [
                'Quit Thoughts and move it to the Trash, or run ',
                { code: 'brew uninstall --cask thoughts' },
                '. Your thoughts stay in their folder until you delete them.',
              ],
            },
          ],
        },
      ],
    },
  ],
}
