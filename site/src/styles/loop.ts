import * as stylex from '@stylexjs/stylex'
import { motion } from './tokens.stylex'

export const loop = stylex.create({
  long: {
    animationDuration: motion.loopLong,
    animationIterationCount: 'infinite',
    animationTimingFunction: 'linear',
    animationFillMode: 'both',
  },
  short: {
    animationDuration: motion.loopShort,
    animationIterationCount: 'infinite',
    animationTimingFunction: 'linear',
    animationFillMode: 'both',
  },
})
