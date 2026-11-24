import * as stylex from '@stylexjs/stylex'
import { media, space, width } from './tokens.stylex'

export const layout = stylex.create({
  column: {
    width: '100%',
    maxWidth: {
      default: width.column,
      [media.wide]: width.columnWide,
    },
    marginInline: 'auto',
    paddingInline: space.gutter,
  },
  narrowBlock: {
    display: {
      default: 'block',
      [media.wide]: 'none',
    },
  },
  wideBlock: {
    display: {
      default: 'none',
      [media.wide]: 'block',
    },
  },
  narrowFlex: {
    display: {
      default: 'flex',
      [media.wide]: 'none',
    },
  },
  wideFlex: {
    display: {
      default: 'none',
      [media.wide]: 'flex',
    },
  },
  narrowInline: {
    display: {
      default: 'inline',
      [media.wide]: 'none',
    },
  },
})
