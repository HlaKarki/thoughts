import * as stylex from '@stylexjs/stylex'
import type { ReactNode } from 'react'
import { color, radius } from '@/styles/tokens.stylex'

type Props = {
  readonly children: ReactNode
  readonly scale: 'full' | 'mini'
  readonly xstyle?: stylex.StyleXStyles
}

export function GlassPanel({ children, scale, xstyle }: Props) {
  return <div {...stylex.props(styles.panel, styles[scale], xstyle)}>{children}</div>
}

const styles = stylex.create({
  panel: {
    display: 'flex',
    flexDirection: 'column',
    overflow: 'clip',
    backgroundColor: color.panel,
    borderWidth: 1,
    borderStyle: 'solid',
    borderColor: color.panelBorder,
  },
  full: {
    borderRadius: radius.r24,
    backdropFilter: 'blur(40px) saturate(180%)',
    WebkitBackdropFilter: 'blur(40px) saturate(180%)',
    boxShadow: color.panelShadow,
  },
  mini: {
    borderRadius: radius.r16,
    backdropFilter: 'blur(24px) saturate(180%)',
    WebkitBackdropFilter: 'blur(24px) saturate(180%)',
    boxShadow: color.panelShadowMini,
  },
})
