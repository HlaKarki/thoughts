import * as stylex from '@stylexjs/stylex'
import type { ReactNode } from 'react'
import { color, font, leading, radius, size } from '@/styles/tokens.stylex'

type Props = {
  readonly children: ReactNode
  readonly xstyle?: stylex.StyleXStyles
}

export function Key({ children, xstyle }: Props) {
  return <kbd {...stylex.props(styles.key, xstyle)}>{children}</kbd>
}

const styles = stylex.create({
  key: {
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'center',
    width: 28,
    height: 28,
    borderRadius: radius.r6,
    borderWidth: 1,
    borderStyle: 'solid',
    borderColor: color.keyBorder,
    backgroundColor: color.key,
    boxShadow: color.keyShadow,
    color: color.keyText,
    fontFamily: font.text,
    fontSize: size.s14,
    lineHeight: leading.l16,
  },
})
