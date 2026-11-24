import * as stylex from '@stylexjs/stylex'
import type { ReactNode } from 'react'
import { color, font, leading, media, size, tracking } from '@/styles/tokens.stylex'

type Props = {
  readonly heading: ReactNode
  readonly muted: string
  readonly body: string
}

export function SectionIntro({ heading, muted, body }: Props) {
  return (
    <div {...stylex.props(styles.intro)}>
      <h2 {...stylex.props(styles.heading)}>
        {heading}
        <br />
        <span {...stylex.props(styles.muted)}>{muted}</span>
      </h2>
      <p {...stylex.props(styles.body)}>{body}</p>
    </div>
  )
}

const styles = stylex.create({
  intro: {
    display: 'flex',
    flexDirection: 'column',
    gap: 16,
  },
  heading: {
    color: color.text,
    fontFamily: font.display,
    fontSize: { default: size.s24, [media.wide]: size.s32 },
    fontWeight: 500,
    lineHeight: { default: leading.l32, [media.wide]: leading.l40 },
    letterSpacing: tracking.display,
  },
  muted: {
    color: color.textMuted,
  },
  body: {
    maxWidth: 600,
    color: color.textMuted,
    fontFamily: font.text,
    fontSize: { default: size.s15, [media.wide]: size.s17 },
    lineHeight: { default: leading.l24, [media.wide]: leading.l26 },
  },
})
