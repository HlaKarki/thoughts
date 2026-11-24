import * as stylex from '@stylexjs/stylex'
import { sequenceStyles } from '@/styles/sequence'

type Props = {
  readonly text: string
  readonly wrapWords?: boolean
  readonly charXstyle: stylex.StyleXStyles
}

export function TypedText({ text, wrapWords = false, charXstyle }: Props) {
  const chars = Array.from(text)
  const typed = chars.map((char, index) => (
    <span key={index} {...stylex.props(styles.char, sequenceStyles.at(index, chars.length), charXstyle)}>
      {char}
    </span>
  ))
  if (!wrapWords) return typed
  const starts = chars.flatMap((char, index) => (index === 0 || (chars[index - 1] === ' ' && char !== ' ') ? [index] : []))
  return starts.map((start, index) => (
    <span key={start} {...stylex.props(styles.word)}>
      {typed.slice(start, starts[index + 1])}
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
  word: {
    whiteSpace: 'nowrap',
  },
})
