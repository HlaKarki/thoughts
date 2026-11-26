import * as stylex from '@stylexjs/stylex'
import { ButtonLink } from '@/components/ButtonLink'
import { CopyCommand } from '@/components/CopyCommand'
import { intro } from '@/content/intro'
import { color, font, leading, media, radius, size, space, tracking, width } from '@/styles/tokens.stylex'

export function Intro() {
  return (
    <section {...stylex.props(styles.intro)}>
      <h1 {...stylex.props(styles.title)}>{intro.title}</h1>
      <p {...stylex.props(styles.lead)}>{intro.lead}</p>
      <div {...stylex.props(styles.actions)}>
        <ButtonLink link={intro.download} xstyle={styles.download} />
        <CopyCommand command={intro.brew} xstyle={styles.brew} />
      </div>
    </section>
  )
}

const styles = stylex.create({
  intro: {
    display: 'flex',
    flexDirection: 'column',
    gap: { default: 14, [media.wide]: 32 },
    width: '100%',
    maxWidth: width.intro,
    marginInline: 'auto',
    paddingInline: space.gutter,
    paddingTop: { default: 40, [media.wide]: 96 },
  },
  title: {
    color: color.text,
    fontFamily: font.display,
    fontSize: { default: size.s32, [media.wide]: size.s40 },
    fontWeight: { default: 600, [media.wide]: 500 },
    lineHeight: { default: '38px', [media.wide]: leading.l48 },
    letterSpacing: { default: tracking.tight, [media.wide]: tracking.display },
    textWrap: { default: 'balance', [media.wide]: 'wrap' },
  },
  lead: {
    color: { default: color.textMuted, [media.wide]: color.textBody },
    fontFamily: { default: font.text, [media.wide]: font.display },
    fontSize: { default: size.s17, [media.wide]: size.s28 },
    lineHeight: { default: leading.l26, [media.wide]: leading.l40 },
    textWrap: { default: 'pretty', [media.wide]: 'wrap' },
    letterSpacing: { default: tracking.leadNarrow, [media.wide]: tracking.lead },
  },
  actions: {
    display: { default: 'none', [media.pointer]: 'flex' },
    flexDirection: { default: 'column', [media.wide]: 'row' },
    alignItems: { default: 'stretch', [media.wide]: 'center' },
    gap: 12,
    paddingTop: { default: 8, [media.wide]: 16 },
  },
  download: {
    flexShrink: 0,
  },
  brew: {
    display: { default: 'none', [media.pointer]: 'flex' },
    flexGrow: { default: 0, [media.wide]: 1 },
    maxWidth: { default: null, [media.wide]: 440 },
  },
})
