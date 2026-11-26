import * as stylex from '@stylexjs/stylex'

type PlayState = 'paused' | 'running'

const paused: PlayState = 'paused'

export const playback = stylex.defineVars({
  state: paused,
})
