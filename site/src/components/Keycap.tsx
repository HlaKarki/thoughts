import * as stylex from '@stylexjs/stylex'
import type { ReactNode } from 'react'
import { color, font, leading, radius, size } from '@/styles/tokens.stylex'

type Props = {
  readonly children: ReactNode
  readonly variant: 'hint' | 'table' | 'offer'
}

export function Keycap({ children, variant }: Props) {
  return <kbd {...stylex.props(styles.base, styles[variant])}>{children}</kbd>
}

const styles = stylex.create({
  base: {
    display: 'inline-flex',
    alignItems: 'center',
    justifyContent: 'center',
    flexShrink: 0,
    fontFamily: font.text,
    whiteSpace: 'nowrap',
  },
  hint: {
    height: 16,
    minWidth: 16,
    paddingInline: 4,
    borderRadius: radius.r4,
    backgroundColor: color.keycap,
    color: color.keycapText,
    fontSize: size.s11,
    lineHeight: leading.l16,
  },
  table: {
    height: 22,
    minWidth: 22,
    paddingInline: 6,
    borderRadius: radius.r5,
    backgroundColor: color.keycap,
    color: color.keycapText,
    fontSize: size.s13,
    lineHeight: leading.l16,
  },
  offer: {
    height: 22,
    minWidth: 22,
    paddingInline: 6,
    borderRadius: radius.r5,
    backgroundColor: color.chipSlot,
    color: color.chipSubtitle,
    fontSize: size.s11,
    lineHeight: leading.l16,
  },
})
