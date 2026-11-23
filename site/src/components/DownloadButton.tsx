import * as stylex from '@stylexjs/stylex'
import type { Link } from '@/content/types'
import { color, font, leading, radius, size } from '@/styles/tokens.stylex'

type Props = {
  readonly link: Link
  readonly xstyle?: stylex.StyleXStyles
}

export function DownloadButton({ link, xstyle }: Props) {
  return (
    <a href={link.href} {...stylex.props(styles.button, xstyle)}>
      {link.label}
    </a>
  )
}

const styles = stylex.create({
  button: {
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'center',
    flexShrink: 0,
    height: 44,
    paddingInline: 24,
    borderRadius: radius.r22,
    backgroundColor: color.accent,
    color: color.onAccent,
    fontFamily: font.text,
    fontSize: size.s15,
    fontWeight: 500,
    lineHeight: leading.l20,
    whiteSpace: 'nowrap',
    outlineOffset: 3,
    transitionProperty: 'filter',
    transitionDuration: '150ms',
    filter: {
      default: null,
      ':hover': 'brightness(1.08)',
    },
  },
})
