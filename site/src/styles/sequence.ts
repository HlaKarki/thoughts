import * as stylex from '@stylexjs/stylex'
import { sequence } from './sequence.stylex'

export const sequenceStyles = stylex.create({
  at: (index: number) => ({
    [sequence.index]: index,
  }),
})
