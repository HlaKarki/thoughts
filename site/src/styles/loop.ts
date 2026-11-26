import * as stylex from '@stylexjs/stylex'
import { playback } from './playback.stylex'
import { motion } from './tokens.stylex'

export const loop = stylex.create({
  run: {
    animationIterationCount: 'infinite',
    animationFillMode: 'both',
    animationTimingFunction: motion.easeOut,
    animationPlayState: playback.state,
  },
  playing: {
    [playback.state]: 'running',
  },
})
