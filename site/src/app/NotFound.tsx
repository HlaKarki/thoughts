import * as stylex from '@stylexjs/stylex'
import { AppIcon } from '@/components/AppIcon'
import { ButtonLink } from '@/components/ButtonLink'
import { notFound } from '@/content/notFound'
import { color, font, leading, media, size, space, tracking } from '@/styles/tokens.stylex'

export function NotFound() {
  return (
    <main {...stylex.props(styles.page)}>
      <AppIcon size={64} decorative xstyle={styles.icon} />
      <h1 {...stylex.props(styles.heading)}>{notFound.heading}</h1>
      <p {...stylex.props(styles.body)}>{notFound.body}</p>
      <ButtonLink link={notFound.home} xstyle={styles.link} />
    </main>
  )
}

const styles = stylex.create({
  page: {
    display: 'flex',
    flexDirection: 'column',
    alignItems: 'center',
    justifyContent: 'center',
    gap: 16,
    minHeight: '100svh',
    paddingInline: space.gutter,
    paddingBlock: 48,
    textAlign: 'center',
  },
  icon: {
    width: { default: 56, [media.wide]: 64 },
    height: { default: 56, [media.wide]: 64 },
    marginBottom: 8,
  },
  heading: {
    color: color.text,
    fontFamily: font.display,
    fontSize: { default: size.s24, [media.wide]: size.s32 },
    fontWeight: 500,
    lineHeight: { default: leading.l32, [media.wide]: leading.l40 },
    letterSpacing: tracking.display,
  },
  body: {
    maxWidth: 440,
    color: color.textMuted,
    fontFamily: font.text,
    fontSize: size.s15,
    lineHeight: leading.l24,
  },
  link: {
    marginTop: 8,
  },
})
