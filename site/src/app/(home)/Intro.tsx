import * as stylex from '@stylexjs/stylex'
import { ButtonLink } from '@/components/ButtonLink'
import { intro } from '@/content/intro'
import { color, font, leading, media, radius, size, space, tracking, width } from '@/styles/tokens.stylex'

export function Intro() {
  return (
    <section {...stylex.props(styles.intro)}>
      <h1 {...stylex.props(styles.title)}>
        {intro.title} <span {...stylex.props(styles.muted)}>{intro.titleMuted}</span>
      </h1>
      <p {...stylex.props(styles.lead)}>{intro.lead}</p>
      <div {...stylex.props(styles.install)}>
        <div {...stylex.props(styles.actions)}>
          <ButtonLink link={intro.download} />
          <code {...stylex.props(styles.brew)}>{intro.brew}</code>
        </div>
        <p {...stylex.props(styles.requirements)}>{intro.requirements}</p>
      </div>
    </section>
  )
}

const styles = stylex.create({
  intro: {
    display: 'flex',
    flexDirection: 'column',
    gap: { default: 24, [media.wide]: 32 },
    width: '100%',
    maxWidth: width.intro,
    marginInline: 'auto',
    paddingInline: space.gutter,
    paddingTop: { default: 48, [media.wide]: 96 },
  },
  title: {
    color: color.text,
    fontFamily: font.display,
    fontSize: { default: size.s28, [media.wide]: size.s40 },
    fontWeight: 500,
    lineHeight: { default: leading.l36, [media.wide]: leading.l48 },
    letterSpacing: { default: tracking.lead, [media.wide]: tracking.display },
  },
  muted: {
    color: color.textMuted,
  },
  lead: {
    color: color.textBody,
    fontFamily: font.display,
    fontSize: { default: size.s20, [media.wide]: size.s28 },
    lineHeight: { default: leading.l28, [media.wide]: leading.l40 },
    letterSpacing: { default: tracking.leadNarrow, [media.wide]: tracking.lead },
  },
  install: {
    display: 'flex',
    flexDirection: 'column',
    gap: 16,
    paddingTop: { default: 8, [media.wide]: 16 },
  },
  actions: {
    display: 'flex',
    flexDirection: { default: 'column', [media.wide]: 'row' },
    alignItems: { default: 'stretch', [media.wide]: 'center' },
    gap: 12,
  },
  brew: {
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'center',
    flexShrink: 0,
    height: 44,
    paddingInline: { default: 0, [media.wide]: 24 },
    borderRadius: radius.r22,
    backgroundColor: color.pill,
    color: color.textBody,
    fontFamily: font.mono,
    fontSize: { default: size.s13, [media.wide]: size.s15 },
    lineHeight: leading.l20,
    whiteSpace: 'nowrap',
    overflowX: 'auto',
    scrollbarWidth: 'none',
    userSelect: 'all',
  },
  requirements: {
    color: color.textMuted,
    fontFamily: font.text,
    fontSize: size.s15,
    lineHeight: leading.l24,
  },
})
