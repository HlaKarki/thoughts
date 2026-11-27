import type { Page } from '../types'

const helper = '/Applications/Thoughts.app/Contents/Helpers/thoughts'

export const mcp: Page = {
  slug: 'mcp',
  label: 'Thoughts for AI agents',
  group: 'guides',
  navLabel: 'For AI agents',
  title: 'A Mac notes app your AI agent can write to: Thoughts MCP',
  description:
    'Thoughts ships an MCP server, so Claude Code, Cursor and other agents can add, search and check off the same Markdown thoughts you keep on your Mac.',
  heading: 'A notes app your AI agent can write to.',
  lead: 'Thoughts keeps the small things you find while you work, one key away on your Mac. Its MCP server gives your agents the same list: an agent can save a finding for later, search what you kept, and check off what it finished.',
  sections: [
    {
      heading: 'What your agent can do',
      blocks: [
        {
          kind: 'list',
          items: [
            [{ code: 'list_thoughts' }, ' lists open thoughts, or done ones too.'],
            [{ code: 'add_thought' }, ' adds a thought from text, or a screenshot thought from an image file.'],
            [{ code: 'search_thoughts' }, ' searches every thought, including the text inside screenshots.'],
            [{ code: 'show_thought' }, ' shows one thought with its source.'],
            [{ code: 'mark_done' }, ' checks a thought off, or opens it again.'],
            [{ code: 'thought_path' }, ' gives the path of a thought\'s file or image, so the agent can read it.'],
          ],
        },
      ],
    },
    {
      heading: 'Add Thoughts to your agent',
      blocks: [
        { kind: 'text', text: ['In Claude Code, run:'] },
        { kind: 'code', label: 'Terminal', code: `claude mcp add thoughts -- ${helper} mcp` },
        {
          kind: 'text',
          text: ['For Cursor, Claude Desktop and any other client that reads an ', { code: 'mcpServers' }, ' config, add:'],
        },
        {
          kind: 'code',
          label: 'mcpServers config',
          code: `{
  "mcpServers": {
    "thoughts": {
      "command": "${helper}",
      "args": ["mcp"]
    }
  }
}`,
        },
        {
          kind: 'text',
          text: [
            'If you installed Thoughts with Homebrew, the ',
            { code: 'thoughts' },
            ' command is already on your PATH, so ',
            { code: 'thoughts' },
            ' works in place of the full path.',
          ],
        },
      ],
    },
    {
      heading: 'You can see which agent saved what',
      blocks: [
        {
          kind: 'text',
          text: [
            'A thought added over MCP records the client\'s name as its source, the same way a thought from Safari records the page. So you can always tell a note from your agent from one you wrote.',
          ],
        },
      ],
    },
    {
      heading: 'Or use the command line',
      blocks: [
        {
          kind: 'text',
          text: [
            'The ',
            { code: 'thoughts' },
            ' command reads and writes the same folder as the app, so scripts and hooks can use it too. Add ',
            { code: '--json' },
            ' for output a program can read.',
          ],
        },
        {
          kind: 'code',
          label: 'Terminal',
          code: `thoughts add "Check the flaky login test"
git log -1 --format=%s | thoughts add
thoughts search invoice --json
thoughts done ke6s`,
        },
      ],
    },
    {
      heading: 'Every thought is a file',
      blocks: [
        {
          kind: 'text',
          text: [
            'Each thought is one Markdown file with its source in the front matter, so an agent that can read files can read your thoughts without any server at all. Edit a file in any editor and the panel shows the change. The full format is in the ',
            { link: { label: 'README', href: 'https://github.com/HlaKarki/thoughts#your-files' } },
            '.',
          ],
        },
      ],
    },
  ],
}
