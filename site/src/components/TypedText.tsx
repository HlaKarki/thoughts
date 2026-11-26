import * as stylex from '@stylexjs/stylex'
import { sequenceStyles } from '@/styles/sequence'
import { reveal } from '@/styles/sequence.stylex'

type Props = {
  readonly text: string
  readonly wrapWords?: boolean
  readonly xstyle?: stylex.StyleXStyles
}

export function TypedText({ text, wrapWords = false, xstyle }: Props) {
  const chars = Array.from(text)
  const typed = chars.map((char, index) => (
    <span key={index} {...stylex.props(styles.char, sequenceStyles.at(index))}>
      {char}
    </span>
  ))
  const starts = chars.flatMap((char, index) => (index === 0 || (chars[index - 1] === ' ' && char !== ' ') ? [index] : []))
  return (
    <span {...stylex.props(xstyle)}>
      {wrapWords
        ? starts.map((start, index) => (
            <span key={start} {...stylex.props(styles.word)}>
              {typed.slice(start, starts[index + 1])}
            </span>
          ))
        : typed}
    </span>
  )
}

const styles = stylex.create({
  char: {
    display: 'inline-block',
    maxWidth: reveal.width,
    overflow: 'clip',
    verticalAlign: 'top',
    whiteSpace: 'pre',
  },
  word: {
    whiteSpace: 'nowrap',
  },
})
