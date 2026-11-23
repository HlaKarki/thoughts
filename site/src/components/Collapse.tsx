import * as stylex from '@stylexjs/stylex'
import type { ReactNode } from 'react'

type Props = {
  readonly children: ReactNode
  readonly element?: 'li' | 'div'
  readonly xstyle?: stylex.StyleXStyles
}

export function Collapse({ children, element: Element = 'div', xstyle }: Props) {
  return (
    <Element {...stylex.props(styles.outer, xstyle)}>
      <div {...stylex.props(styles.inner)}>{children}</div>
    </Element>
  )
}

const styles = stylex.create({
  outer: {
    display: 'grid',
    gridTemplateRows: '1fr',
    flexShrink: 0,
  },
  inner: {
    display: 'flex',
    flexDirection: 'column',
    minHeight: 0,
    overflow: 'clip',
  },
})
