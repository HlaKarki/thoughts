type Thought = {
  readonly text: string
  readonly time: string
}

export const thoughts = {
  dough: { text: 'Let the dough rest for 30 minutes before you add the salt.', time: '10:24' },
  oven: { text: 'Which one goes in the oven?', time: '10:05' },
} as const satisfies Record<string, Thought>
