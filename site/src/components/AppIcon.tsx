import * as stylex from '@stylexjs/stylex'
import { site } from '@/content/site'

type Props = {
  readonly size: number
  readonly decorative?: boolean
  readonly xstyle?: stylex.StyleXStyles
}

export function AppIcon({ size, decorative = false, xstyle }: Props) {
  return (
    <picture {...stylex.props(styles.picture, xstyle)}>
      <source srcSet={site.icon.dark} media="(prefers-color-scheme: dark)" />
      <img
        src={site.icon.light}
        alt={decorative ? '' : site.icon.alt}
        width={size}
        height={size}
        {...stylex.props(styles.image)}
      />
    </picture>
  )
}

const styles = stylex.create({
  picture: {
    display: 'block',
    flexShrink: 0,
  },
  image: {
    display: 'block',
    width: '100%',
    height: '100%',
  },
})
