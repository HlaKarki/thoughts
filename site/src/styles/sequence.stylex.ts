import * as stylex from '@stylexjs/stylex'

export const sequence = stylex.defineVars({
  index: '0',
  typed: stylex.types.number(1000),
})

export const reveal = stylex.defineConsts({
  width: `calc((${sequence.typed} - ${sequence.index} - 1) * 100em)`,
})
