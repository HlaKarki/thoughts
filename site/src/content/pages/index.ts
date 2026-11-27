import type { Page } from '../types'
import { appleQuickNote } from './appleQuickNote'
import { copper } from './copper'
import { drafts } from './drafts'
import { faq } from './faq'
import { mcp } from './mcp'
import { raycastNotes } from './raycastNotes'
import { scratchpad } from './scratchpad'
import { screenshots } from './screenshots'
import { selectedText } from './selectedText'
import { tot } from './tot'

export const pages: ReadonlyArray<Page> = [
  scratchpad,
  selectedText,
  screenshots,
  mcp,
  copper,
  appleQuickNote,
  raycastNotes,
  drafts,
  tot,
  faq,
]

export function findPage(slug: string) {
  return pages.find((page) => page.slug === slug)
}
