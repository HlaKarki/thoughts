import * as stylex from '@stylexjs/stylex'
import { useId } from 'react'

export function Grain() {
  const filter = useId()
  return (
    <svg aria-hidden="true" {...stylex.props(styles.grain)}>
      <filter id={filter}>
        <feTurbulence type="fractalNoise" baseFrequency="0.85" numOctaves={2} stitchTiles="stitch" />
        <feColorMatrix type="saturate" values="0" />
      </filter>
      <rect width="100%" height="100%" filter={`url(#${filter})`} />
    </svg>
  )
}

const styles = stylex.create({
  grain: {
    position: 'absolute',
    inset: 0,
    width: '100%',
    height: '100%',
    opacity: 0.3,
    mixBlendMode: 'overlay',
    pointerEvents: 'none',
  },
})
