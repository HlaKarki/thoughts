import * as stylex from '@stylexjs/stylex'
import { sequenceStyles } from '@/styles/sequence'

type Props = {
  readonly text: string
  readonly charXstyle: stylex.StyleXStyles
}

export function TypedText({ text, charXstyle }: Props) {
  const chars = Array.from(text)
  return chars.map((char, index) => (
    <span key={index} {...stylex.props(styles.char, sequenceStyles.at(index, chars.length), charXstyle)}>
      {char}
    </span>
  ))
}

const styles = stylex.create({
  char: {
    display: 'inline-block',
    overflow: 'clip',
    verticalAlign: 'top',
    whiteSpace: 'pre',
  },
})
