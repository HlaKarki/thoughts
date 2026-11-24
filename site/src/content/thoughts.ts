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
  tram: { text: 'It fills up after 10, so get on early at Martim Moniz.', time: '10:24' },
  sitter: { text: 'Ask the sitter for a photo every day', time: '10:05' },
  clone: { text: "structuredClone copies Maps, Sets and Dates, but it can't copy functions.", time: '11:08' },
  fridge: { text: 'This one goes on the fridge', time: '8:47' },
  review: { text: 'Design review moved to Thursday at 2. Bring the new onboarding flow.', time: '9:30' },
  water: { text: 'The water is off Thursday from 9 to noon.', time: '10:12' },
  table: { text: 'Book a table for Saturday', time: '10:40' },
  walden: { text: 'Walden, p. 90:', time: '9:15' },
  signups: { text: 'Ask why signups dipped in March', time: '10:32' },
} as const satisfies Record<string, Thought>

export const today: Day = { year: 2026, month: 11, date: 23 }

export const sources = {
  guide: { app: 'Safari', bundle: 'com.apple.Safari', window: 'Lisbon in three days' },
  slack: { app: 'Slack', bundle: 'com.tinyspeck.slackmacgap', window: '#design' },
  messages: { app: 'Messages', bundle: 'com.apple.MobileSMS', window: 'Home' },
} as const satisfies Record<string, Source>

export function sourceLine(source: Source): string {
  return `${source.app}: ${source.window}`
}
