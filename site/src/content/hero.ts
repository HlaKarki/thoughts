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
  readonly caption: string
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
  label: `The Thoughts panel sits beside a Lisbon travel guide in ${sources.guide.app}, and the sentence you selected on the page is now the newest thought.`,
  caption: `Select text in ${sources.guide.app}, press Shift twice, and it lands in the panel.`,
  menuBar: {
    app: sources.guide.app,
    menus: ['File', 'Edit', 'View', 'History', 'Bookmarks', 'Window', 'Help'],
    clock: `${clockDate(today)} ${thoughts.tram.time} AM`,
  },
  browser: {
    address: 'example.com',
    eyebrow: 'Travel',
    title: sources.guide.window,
    intro: 'Three days is enough for the old town, the river and one long lunch.',
    photo: site.photos.tram,
    heading: 'Getting around',
    paragraph: {
      before: 'Tram 28 climbs through Graça and Alfama on the old tracks. ',
      selected: thoughts.tram.text,
      after: ' A day pass covers the tram and the metro, and you can buy it at any metro station.',
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
      { kind: 'text', text: 'Buy a travel adapter', time: 'Sat', done: true },
      { kind: 'text', text: 'Renew the domain before Friday', time: '9:12' },
      { kind: 'text', text: 'Check in for the flight before 6', time: '9:41' },
      {
        kind: 'image',
        image: site.photos.cat,
        note: thoughts.sitter.text,
        time: thoughts.sitter.time,
      },
      { kind: 'text', ...thoughts.tram },
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
