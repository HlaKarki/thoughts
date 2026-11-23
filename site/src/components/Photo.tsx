import * as stylex from '@stylexjs/stylex'
import type { ReactNode } from 'react'

type Props = {
  readonly src: string
  readonly alt: string
  readonly xstyle: stylex.StyleXStyles
  readonly children?: ReactNode
}

export function Photo({ src, alt, xstyle, children }: Props) {
  return (
    <div
      role={alt ? 'img' : undefined}
      aria-label={alt || undefined}
      aria-hidden={alt ? undefined : true}
      {...stylex.props(styles.photo, xstyle, styles.source(`url("${src}")`))}
    >
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
