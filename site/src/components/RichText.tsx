import * as stylex from '@stylexjs/stylex'
import type { Rich } from '@/content/types'
import { color, font, leading, size } from '@/styles/tokens.stylex'

type Props = {
  readonly text: Rich
  readonly codeXstyle?: stylex.StyleXStyles
}

export function RichText({ text, codeXstyle }: Props) {
  return (
    <>
      {text.map((part, index) =>
        typeof part === 'string' ? (
          part
        ) : 'code' in part ? (
          <code key={index} {...stylex.props(styles.code, codeXstyle)}>
            {part.code}
          </code>
        ) : 'link' in part ? (
          <a key={index} href={part.link.href} {...stylex.props(styles.link)}>
            {part.link.label}
          </a>
        ) : (
          <strong key={index} {...stylex.props(styles.strong)}>
            {part.strong}
          </strong>
        ),
      )}
    </>
  )
}

const styles = stylex.create({
  code: {
    color: color.textCode,
    fontFamily: font.mono,
    fontSize: size.s14,
    lineHeight: leading.l16,
  },
  link: {
    color: color.accent,
    textDecorationLine: { default: 'none', ':hover': 'underline' },
  },
  strong: {
    fontWeight: 600,
  },
})
