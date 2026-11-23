import { site } from './site'
import { clockDate } from '@/lib/stamp'
import { sources, thoughts, today } from './thoughts'

export type PanelRow =
  | {
      readonly kind: 'text'
      readonly text: string
      readonly time: string
      readonly done?: boolean
      readonly layout?: 'wide' | 'narrow'
    }
  | {
      readonly kind: 'image'
      readonly image: string
      readonly note: string
      readonly time: string
    }

export type KeyHint = {
  readonly label: string
  readonly keys: string
}

type Hero = {
  readonly label: string
  readonly menuBar: {
    readonly app: string
    readonly menus: ReadonlyArray<string>
    readonly clock: string
  }
  readonly browser: {
    readonly address: string
    readonly eyebrow: string
    readonly title: string
    readonly intro: string
    readonly photo: string
    readonly heading: string
    readonly paragraph: {
      readonly before: string
      readonly selected: string
      readonly after: string
    }
  }
  readonly panel: {
    readonly search: string
    readonly rows: ReadonlyArray<PanelRow>
    readonly composer: string
    readonly hints: ReadonlyArray<KeyHint>
  }
}

export const hero: Hero = {
  label: `The Thoughts panel sits beside a sourdough recipe in ${sources.recipe.app}, and the sentence you selected on the page is now the newest thought.`,
  menuBar: {
    app: sources.recipe.app,
    menus: ['File', 'Edit', 'View', 'History', 'Bookmarks', 'Window', 'Help'],
    clock: `${clockDate(today)} ${thoughts.dough.time} AM`,
  },
  browser: {
    address: 'example.com',
    eyebrow: 'Recipes',
    title: sources.recipe.window,
    intro: 'Two days from start to finish, and the dough does most of the work.',
    photo: site.photos.bread,
    heading: 'Mix and rest',
    paragraph: {
      before: 'Mix the flour and water until no dry bits remain. ',
      selected: thoughts.dough.text,
      after: ' The rest gives the flour time to soak up the water, so the dough is easier to knead.',
    },
  },
  panel: {
    search: 'Search thoughts',
    rows: [
      {
        kind: 'text',
        text: 'Every action should be reachable from the keyboard, and focus should always be visible.',
        time: 'Wed',
        layout: 'narrow',
      },
      {
        kind: 'text',
        text: 'A ring with at least 3:1 contrast against its background works on light and dark pages. Never remove the outline.',
        time: 'Wed',
        layout: 'narrow',
      },
      { kind: 'text', text: 'Bring the spare cable on Monday', time: 'Thu', done: true },
      {
        kind: 'text',
        text: 'Write up the notes from the Tuesday call and share them with everyone who missed it, then file the follow ups.',
        time: 'Thu',
        layout: 'wide',
      },
      { kind: 'text', text: 'Order a new charger', time: 'Fri', done: true },
      { kind: 'text', text: 'Look up train times for Saturday and book seats on the early train', time: 'Fri' },
      {
        kind: 'text',
        text: 'Ask the printer for a proof on the heavier paper before we order all 200 copies, and check that delivery still lands before the fair.',
        time: 'Sat',
      },
      { kind: 'text', text: 'Buy more flour', time: 'Sat', done: true },
      { kind: 'text', text: 'Renew the domain before Friday', time: '9:12' },
      { kind: 'text', text: 'Feed the starter before bed', time: '9:41' },
      {
        kind: 'image',
        image: site.photos.cat,
        note: thoughts.oven.text,
        time: thoughts.oven.time,
      },
      { kind: 'text', ...thoughts.dough },
    ],
    composer: 'Add a thought',
    hints: [
      { label: 'Select', keys: '↑' },
      { label: 'Paste', keys: '⌘V' },
      { label: 'Search', keys: '⌘F' },
      { label: 'Hide', keys: 'esc' },
    ],
  },
}
