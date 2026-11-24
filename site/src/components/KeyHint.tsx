import * as stylex from '@stylexjs/stylex'
import { Keycap } from './Keycap'
import { color, font, leading, size } from '@/styles/tokens.stylex'

type Props = {
  readonly label: string
  readonly keys: string
}

export function KeyHint({ label, keys }: Props) {
  return (
    <span {...stylex.props(styles.hint)}>
      <span {...stylex.props(styles.label)}>{label}</span>
      <Keycap variant="hint">{keys}</Keycap>
    </span>
  )
}

const styles = stylex.create({
  hint: {
    display: 'flex',
    alignItems: 'center',
    gap: 5,
  },
  label: {
    color: color.keycapText,
    fontFamily: font.text,
    fontSize: size.s11,
    lineHeight: leading.l16,
  },
})
