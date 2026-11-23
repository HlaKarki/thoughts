import * as stylex from '@stylexjs/stylex'
import type { ReactNode } from 'react'

type Props = {
  readonly src: string
  readonly xstyle: stylex.StyleXStyles
  readonly children?: ReactNode
}

export function Photo({ src, xstyle, children }: Props) {
  return (
    <div aria-hidden {...stylex.props(styles.photo, xstyle, styles.source(`url("${src}")`))}>
      {children}
    </div>
  )
}

const styles = stylex.create({
  photo: {
    position: 'relative',
    flexShrink: 0,
    overflow: 'clip',
    backgroundRepeat: 'no-repeat',
  },
  source: (image: string) => ({
    backgroundImage: image,
  }),
})
