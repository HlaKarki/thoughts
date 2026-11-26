import * as stylex from '@stylexjs/stylex'
import { useRef, type ReactNode } from 'react'
import { Grain } from '@/components/Grain'
import { useLoopPlayback } from '@/lib/playback'
import { loop } from '@/styles/loop'
import { media, radius, scene } from '@/styles/tokens.stylex'

type Props = {
  readonly label: string
  readonly children: ReactNode
}

export function Tile({ label, children }: Props) {
  const ref = useRef<HTMLDivElement>(null)
  const playing = useLoopPlayback(ref)
  return (
    <div ref={ref} role="img" aria-label={label} {...stylex.props(styles.tile, playing && loop.playing)}>
      <Grain />
      <div aria-hidden {...stylex.props(styles.stage)}>
        {children}
      </div>
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
