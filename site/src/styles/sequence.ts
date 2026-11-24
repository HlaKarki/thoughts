import * as stylex from '@stylexjs/stylex'
import { sequence } from './sequence.stylex'

export const sequenceStyles = stylex.create({
  at: (index: number, count: number) => ({
    [sequence.index]: index,
    [sequence.count]: count,
  }),
})
