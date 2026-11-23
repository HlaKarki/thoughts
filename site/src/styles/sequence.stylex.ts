import * as stylex from '@stylexjs/stylex'

export const sequence = stylex.defineVars({
  index: '0',
  count: '1',
})

export const reveal = stylex.defineConsts({
  widthHidden: `calc((${sequence.index} + 1) * -1000em)`,
  widthShown: `calc((${sequence.count} - ${sequence.index}) * 1000em)`,
  clipHidden: `inset(0 calc((${sequence.index} + 1) * 100%) 0 0)`,
  clipShown: `inset(0 calc((${sequence.index} + 1 - ${sequence.count}) * 100%) 0 0)`,
})
