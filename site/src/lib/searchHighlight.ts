const wordCharacter = /[\p{L}\p{N}]/u

export type BoldWindow = {
  readonly from: number
  readonly to: number | null
}

export type BoldSegment = {
  readonly text: string
  readonly windows: ReadonlyArray<BoldWindow>
}

function fold(char: string): string {
  return char.normalize('NFD').replace(/\p{M}/gu, '').toLocaleLowerCase()
}

export function searchTerms(query: string): Array<string> {
  return query.split(/\s+/u).filter((term) => wordCharacter.test(term))
}

function matchesAt(chars: ReadonlyArray<string>, needle: ReadonlyArray<string>, start: number): boolean {
  return needle.every((char, offset) => fold(chars[start + offset] ?? '') === fold(char))
}

export function boldRanges(text: string, terms: ReadonlyArray<string>): Array<readonly [number, number]> {
  const chars = Array.from(text)
  const found: Array<readonly [number, number]> = []
  for (const term of terms) {
    const needle = Array.from(term)
    if (!needle.length) continue
    let cursor = 0
    while (cursor < chars.length) {
      let start = cursor
      while (start + needle.length <= chars.length && !matchesAt(chars, needle, start)) start++
      if (start + needle.length > chars.length) break
      const startsWord = start === 0 || !wordCharacter.test(chars[start - 1] ?? '')
      if (startsWord) found.push([start, start + needle.length])
      cursor = start + needle.length
    }
  }
  return found
}

function boldAt(text: string, query: string): Array<boolean> {
  const bold = Array.from(text, () => false)
  if (!query.trim()) return bold
  for (const [start, end] of boldRanges(text, searchTerms(query))) {
    for (let index = start; index < end; index++) bold[index] = true
  }
  return bold
}

export function typedBold(text: string, query: string): Array<BoldSegment> {
  const chars = Array.from(text)
  const typed = Array.from(query)
  const byPrefix = typed.map((_, index) => boldAt(text, typed.slice(0, index + 1).join('')))
  const windowsAt = chars.map((_, char) => {
    const windows: Array<BoldWindow> = []
    let from: number | null = null
    byPrefix.forEach((bold, index) => {
      const length = index + 1
      if (bold[char] && from === null) from = length
      if (!bold[char] && from !== null) {
        windows.push({ from, to: length })
        from = null
      }
    })
    if (from !== null) windows.push({ from, to: null })
    return windows
  })
  const segments: Array<BoldSegment> = []
  chars.forEach((char, index) => {
    const windows = windowsAt[index] ?? []
    const last = segments.at(-1)
    if (last && JSON.stringify(last.windows) === JSON.stringify(windows)) {
      segments[segments.length - 1] = { text: last.text + char, windows }
    } else {
      segments.push({ text: char, windows })
    }
  })
  return segments
}
