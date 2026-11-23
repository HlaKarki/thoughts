import { site } from './site'

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
      readonly alt: string
      readonly note: string
      readonly time: string
    }

export type TextRun = {
  readonly text: string
  readonly selected?: boolean
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
    readonly photoAlt: string
    readonly heading: string
    readonly paragraph: ReadonlyArray<ReadonlyArray<TextRun>>
  }
  readonly panel: {
    readonly search: string
    readonly menuLabel: string
    readonly rows: ReadonlyArray<PanelRow>
    readonly composer: string
    readonly hints: ReadonlyArray<KeyHint>
  }
}

export const hero: Hero = {
  label: 'Thoughts open beside a recipe page in Safari',
  menuBar: {
    app: 'Safari',
    menus: ['File', 'Edit', 'View', 'History', 'Bookmarks', 'Window', 'Help'],
    clock: 'Mon Nov 23 10:24 AM',
  },
  browser: {
    address: 'example.com',
    eyebrow: 'Recipes',
    title: 'Sourdough, step by step',
    intro: 'Two days from start to finish, and the dough does most of the work.',
    photo: site.photos.bread,
    photoAlt: 'A round sourdough loaf on a board.',
    heading: 'Mix and rest',
    paragraph: [
      [{ text: 'Mix the flour and water until no dry bits remain. ' }, { text: 'Let the dough rest for 30', selected: true }],
      [{ text: 'minutes before you add the salt.', selected: true }, { text: ' The rest gives the flour time to soak up the' }],
      [{ text: 'water, so the dough is easier to knead.' }],
    ],
  },
  panel: {
    search: 'Search thoughts',
    menuLabel: 'More',
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
        alt: 'A screenshot of an orange cat sitting like a loaf, with a red box around it.',
        note: 'Which one goes in the oven?',
        time: '10:05',
      },
      { kind: 'text', text: 'Let the dough rest for 30 minutes before you add the salt.', time: '10:24' },
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
