import * as stylex from '@stylexjs/stylex'
import type { ReactNode } from 'react'
import { color, font, leading, radius, size } from '@/styles/tokens.stylex'

type Props = {
  readonly time: string
  readonly done?: boolean
  readonly children: ReactNode
  readonly xstyle?: stylex.StyleXStyles
}

export function ThoughtRow({ time, done = false, children, xstyle }: Props) {
  return (
    <li {...stylex.props(styles.row, xstyle)}>
      <div {...stylex.props(styles.body, done && styles.done)}>{children}</div>
      <span {...stylex.props(styles.time, done && styles.doneTime)}>{time}</span>
    </li>
  )
}

const styles = stylex.create({
  row: {
    display: 'flex',
    alignItems: 'start',
    flexShrink: 0,
    gap: 10,
    paddingBlock: 8,
    paddingInline: 6,
    borderRadius: radius.r8,
    fontFamily: font.text,
  },
  body: {
    display: 'flex',
    flexDirection: 'column',
    gap: 6,
    flexGrow: 1,
    flexBasis: 0,
    minWidth: 0,
    color: color.rowText,
    fontSize: size.s13,
    lineHeight: leading.l18,
  },
  done: {
    color: color.rowDone,
    textDecorationLine: 'line-through',
    textDecorationThickness: '1px',
  },
  time: {
    flexShrink: 0,
    width: 40,
    color: color.rowTime,
    fontSize: size.s11,
    lineHeight: leading.l18,
    textAlign: 'right',
  },
  doneTime: {
    color: color.rowDone,
  },
})
