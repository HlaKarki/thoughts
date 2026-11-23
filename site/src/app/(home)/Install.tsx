import * as stylex from '@stylexjs/stylex'
import { AppIcon } from '@/components/AppIcon'
import { DownloadButton } from '@/components/DownloadButton'
import { RichText } from '@/components/RichText'
import { install } from '@/content/install'
import { layout } from '@/styles/layout'
import { color, font, leading, media, radius, size, space, tracking } from '@/styles/tokens.stylex'

export function Install() {
  return (
    <section id={install.id} {...stylex.props(layout.column, styles.section)}>
      <div {...stylex.props(styles.card)}>
        <div {...stylex.props(styles.top)}>
          <div {...stylex.props(styles.about)}>
            <AppIcon size={64} decorative xstyle={styles.icon} />
            <h2 {...stylex.props(styles.heading)}>{install.heading}</h2>
            <p {...stylex.props(styles.body)}>{install.body}</p>
          </div>
          <div {...stylex.props(styles.download)}>
            <DownloadButton link={install.download} />
            <p {...stylex.props(styles.requirement)}>{install.requirement}</p>
          </div>
        </div>
        <div {...stylex.props(styles.brew)}>
          <p {...stylex.props(styles.brewTitle)}>{install.brewTitle}</p>
          <code {...stylex.props(styles.command)}>{install.brew}</code>
        </div>
        <p {...stylex.props(styles.footnote)}>
          <RichText text={install.footnote} codeXstyle={styles.footnoteCode} />
        </p>
      </div>
    </section>
  )
}

const styles = stylex.create({
  section: {
    paddingTop: { default: space.sectionTop, [media.wide]: space.sectionTopWide },
    scrollMarginTop: 24,
  },
  card: {
    display: 'flex',
    flexDirection: 'column',
    gap: { default: 24, [media.wide]: 32 },
    padding: { default: 24, [media.wide]: 40 },
    borderRadius: { default: radius.r20, [media.wide]: radius.r24 },
    borderWidth: 1,
    borderStyle: 'solid',
    borderColor: color.hairline,
    backgroundColor: color.card,
    fontFamily: font.text,
  },
  top: {
    display: 'flex',
    flexDirection: { default: 'column', [media.wide]: 'row' },
    alignItems: { default: 'start', [media.wide]: 'end' },
    justifyContent: 'space-between',
    gap: { default: 24, [media.wide]: 40 },
  },
  about: {
    display: 'flex',
    flexDirection: 'column',
    gap: 16,
    width: { default: '100%', [media.wide]: 560 },
  },
  icon: {
    width: { default: 56, [media.wide]: 64 },
    height: { default: 56, [media.wide]: 64 },
  },
  heading: {
    paddingTop: 8,
    color: color.text,
    fontFamily: font.display,
    fontSize: { default: size.s24, [media.wide]: size.s32 },
    fontWeight: 500,
    lineHeight: { default: leading.l32, [media.wide]: leading.l40 },
    letterSpacing: tracking.display,
  },
  body: {
    color: color.textMuted,
    fontSize: size.s15,
    lineHeight: leading.l24,
  },
  download: {
    display: 'flex',
    flexDirection: 'column',
    alignItems: { default: 'start', [media.wide]: 'end' },
    flexShrink: 0,
    gap: 12,
  },
  requirement: {
    color: color.textMuted,
    fontSize: size.s13,
    lineHeight: leading.l16,
  },
  brew: {
    display: 'flex',
    flexDirection: 'column',
    overflow: 'clip',
    borderRadius: radius.r12,
    borderWidth: 1,
    borderStyle: 'solid',
    borderColor: color.hairline,
    backgroundColor: color.inset,
  },
  brewTitle: {
    display: 'flex',
    alignItems: 'center',
    height: 44,
    paddingInline: { default: 16, [media.wide]: 20 },
    borderBottomWidth: 1,
    borderBottomStyle: 'solid',
    borderBottomColor: color.hairline,
    color: color.textBody,
    fontSize: size.s13,
    lineHeight: leading.l16,
  },
  command: {
    padding: { default: 16, [media.wide]: 20 },
    color: color.textBody,
    fontFamily: font.mono,
    fontSize: { default: size.s13, [media.wide]: size.s14 },
    lineHeight: leading.l20,
    overflowWrap: 'anywhere',
    userSelect: 'all',
  },
  footnote: {
    color: color.textMuted,
    fontSize: size.s13,
    lineHeight: leading.l20,
  },
  footnoteCode: {
    fontSize: size.s12,
  },
})
