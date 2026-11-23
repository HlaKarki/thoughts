import type { Day } from '@/lib/stamp'

type Thought = {
  readonly text: string
  readonly time: string
}

type Source = {
  readonly app: string
  readonly bundle: string
  readonly window: string
}

export const thoughts = {
  dough: { text: 'Let the dough rest for 30 minutes before you add the salt.', time: '10:24' },
  oven: { text: 'Which one goes in the oven?', time: '10:05' },
} as const satisfies Record<string, Thought>

export const today: Day = { year: 2026, month: 11, date: 23 }

export const sources = {
  recipe: { app: 'Safari', bundle: 'com.apple.Safari', window: 'Sourdough, step by step' },
  catPhoto: { app: 'Preview', bundle: 'com.apple.Preview', window: 'IMG_0412.jpeg' },
} as const satisfies Record<string, Source>

export function sourceLine(source: Source): string {
  return `${source.app}: ${source.window}`
}
