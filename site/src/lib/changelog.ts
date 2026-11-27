import changelogMarkdown from '../../../CHANGELOG.md?raw'
import type { Block, Rich, Section } from '@/content/types'

function inline(text: string): Rich {
  return text.split('`').map((part, index) => (index % 2 === 1 ? { code: part } : part))
}

function versionHeading(line: string) {
  const match = /^(\S+) \((\d{4})-(\d{2})-(\d{2})\)$/.exec(line)
  if (!match) return line
  const [, version, year, month, day] = match
  const date = new Date(Date.UTC(Number(year), Number(month) - 1, Number(day)))
  const shown = date.toLocaleDateString('en-US', { month: 'long', day: 'numeric', year: 'numeric', timeZone: 'UTC' })
  return `${version}, ${shown}`
}

export function changelogSections(markdown: string = changelogMarkdown): ReadonlyArray<Section> {
  const sections: Array<{ heading: string; blocks: Array<Block> }> = []
  let items: Array<Rich> | null = null
  let unreleased = false

  for (const raw of markdown.split('\n')) {
    const line = raw.trim()
    const current = sections.at(-1)
    if (line.startsWith('## ')) {
      unreleased = line === '## Unreleased'
      if (!unreleased) sections.push({ heading: versionHeading(line.slice(3)), blocks: [] })
      items = null
    } else if (!current || unreleased) {
      continue
    } else if (line.startsWith('### ')) {
      current.blocks.push({ kind: 'text', text: [{ strong: line.slice(4) }] })
      items = null
    } else if (line.startsWith('- ')) {
      if (!items) {
        items = []
        current.blocks.push({ kind: 'list', items })
      }
      items.push(inline(line.slice(2)))
    } else if (line) {
      current.blocks.push({ kind: 'text', text: inline(line) })
      items = null
    }
  }

  return sections
}
