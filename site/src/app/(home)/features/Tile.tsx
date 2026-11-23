import * as stylex from '@stylexjs/stylex'
import type { ReactNode } from 'react'
import { Grain } from '@/components/Grain'
import { media, radius, scene } from '@/styles/tokens.stylex'

type Props = {
  readonly label: string
  readonly children: ReactNode
}

export function Tile({ label, children }: Props) {
  return (
    <div role="img" aria-label={label} {...stylex.props(styles.tile)}>
      <Grain />
      <div {...stylex.props(styles.stage)}>{children}</div>
    </div>
  )
}

const styles = stylex.create({
  tile: {
    position: 'relative',
    width: '100%',
    height: { default: 400, [media.wide]: 320 },
    overflow: 'clip',
    borderRadius: radius.r16,
    backgroundImage: scene.tile,
  },
  stage: {
    position: 'relative',
    width: { default: 358, [media.wide]: 500 },
    height: '100%',
    marginInline: 'auto',
  },
})
