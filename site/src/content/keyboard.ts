type Shortcut = {
  readonly action: string
  readonly keys: ReadonlyArray<string>
}

type Group = {
  readonly title: string
  readonly shortcuts: ReadonlyArray<Shortcut>
}

type Keyboard = {
  readonly heading: string
  readonly headingMuted: string
  readonly body: string
  readonly anywhere: Group
  readonly panel: Group
  readonly selected: Group
  readonly note: string
}

export const keyboard: Keyboard = {
  heading: 'Thoughts works from the keyboard.',
  headingMuted: 'Two keys work in any app, and the rest work in the panel.',
  body: 'Thoughts lives in the menu bar with no Dock icon and waits until you call it. Press ⌘K with a thought selected to see every action you can take on it.',
  anywhere: {
    title: 'Anywhere',
    shortcuts: [
      { action: 'Show or hide the panel', keys: ['⌃⌥N'] },
      { action: 'Save the selected text or what you just copied', keys: ['⇧⇧'] },
    ],
  },
  panel: {
    title: 'In the panel',
    shortcuts: [
      { action: 'Add what you typed as a thought', keys: ['Return'] },
      { action: 'Select the newest thought', keys: ['↑'] },
      { action: 'Search your thoughts', keys: ['⌘F'] },
      { action: 'Hide the panel', keys: ['Esc'] },
    ],
  },
  selected: {
    title: 'With a thought selected',
    shortcuts: [
      { action: 'Move the selection', keys: ['↑', '↓'] },
      { action: 'Edit the text', keys: ['Return'] },
      { action: 'Mark it done or not done', keys: ['⌘Return'] },
      { action: 'Preview the thought', keys: ['Space'] },
      { action: 'Copy the thought', keys: ['⌘C'] },
      { action: 'Copy the file path', keys: ['⇧⌘C'] },
      { action: 'Open the page or app it came from', keys: ['⌘O'] },
      { action: 'Show the file in Finder', keys: ['⌘R'] },
      { action: 'Move the file to the Trash', keys: ['⌘⌫'] },
      { action: 'Show every action', keys: ['⌘K'] },
      { action: 'Go back to the text field', keys: ['Esc'] },
    ],
  },
  note: 'You can also drop text, images or files on the panel. In other apps, choose Add to Thoughts in the Share menu.',
}
