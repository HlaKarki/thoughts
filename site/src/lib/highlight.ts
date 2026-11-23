import type { Rich } from '@/content/types'

export function highlight(text: string, query: string): Rich {
  if (query === '') return [text]
  const parts: Array<Rich[number]> = []
  const haystack = text.toLocaleLowerCase()
  const needle = query.toLocaleLowerCase()
  let start = 0
  for (let found = haystack.indexOf(needle); found !== -1; found = haystack.indexOf(needle, start)) {
    if (found > start) parts.push(text.slice(start, found))
    parts.push({ strong: text.slice(found, found + query.length) })
    start = found + query.length
  }
  if (start < text.length) parts.push(text.slice(start))
  return parts
}
