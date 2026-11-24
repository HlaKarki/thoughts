import * as stylex from '@stylexjs/stylex'
import type { ReactNode } from 'react'
import { RichText } from '@/components/RichText'
import type { Rich } from '@/content/types'
import { color, font, leading, media, size } from '@/styles/tokens.stylex'

type Props = {
  readonly heading: string
  readonly body: Rich
  readonly tile: ReactNode
}

export function FeatureCard({ heading, body, tile }: Props) {
  return (
    <article {...stylex.props(styles.card)}>
      {tile}
      <div {...stylex.props(styles.text)}>
        <h3 {...stylex.props(styles.heading)}>{heading}</h3>
        <p {...stylex.props(styles.body)}>
          <RichText text={body} />
        </p>
      </div>
    </article>
  )
}

const styles = stylex.create({
  card: {
    display: 'flex',
    flexDirection: 'column',
    minWidth: 0,
  },
  text: {
    display: 'flex',
    flexDirection: 'column',
    gap: 8,
    paddingTop: { default: 20, [media.wide]: 24 },
    fontFamily: font.text,
  },
  heading: {
    color: color.text,
    fontSize: size.s17,
    fontWeight: 600,
    lineHeight: leading.l24,
  },
  body: {
    maxWidth: { default: null, [media.wide]: 470 },
    color: color.textMuted,
    fontSize: size.s15,
    lineHeight: leading.l24,
  },
})
