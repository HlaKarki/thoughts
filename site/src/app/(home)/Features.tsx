import * as stylex from '@stylexjs/stylex'
import { features } from '@/content/features'
import { layout } from '@/styles/layout'
import { color, font, leading, media, size, space, tracking } from '@/styles/tokens.stylex'
import { AgentsTile } from './features/AgentsTile'
import { FeatureCard } from './features/FeatureCard'
import { MarkdownTile } from './features/MarkdownTile'
import { PrivacyTile } from './features/PrivacyTile'
import { ScreenshotTile } from './features/ScreenshotTile'
import { SearchTile } from './features/SearchTile'
import { SelectionTile } from './features/SelectionTile'

const cards = [
  { content: features.selection, Tile: SelectionTile },
  { content: features.screenshot, Tile: ScreenshotTile },
  { content: features.search, Tile: SearchTile },
  { content: features.markdown, Tile: MarkdownTile },
  { content: features.agents, Tile: AgentsTile },
  { content: features.privacy, Tile: PrivacyTile },
] as const

export function Features() {
  const [first, second] = features.heading
  return (
    <section {...stylex.props(layout.column, styles.section)}>
      <div {...stylex.props(styles.intro)}>
        <h2 {...stylex.props(styles.heading)}>
          {first} <br {...stylex.props(layout.narrowInline)} />
          {second}
          <br />
          <span {...stylex.props(styles.muted)}>{features.headingMuted}</span>
        </h2>
        <p {...stylex.props(styles.body)}>{features.body}</p>
      </div>
      <div {...stylex.props(styles.grid)}>
        {cards.map(({ content, Tile }) => (
          <FeatureCard key={content.heading} heading={content.heading} body={content.body} tile={<Tile />} />
        ))}
      </div>
    </section>
  )
}

const styles = stylex.create({
  section: {
    display: 'flex',
    flexDirection: 'column',
    gap: { default: 32, [media.wide]: 56 },
    paddingTop: { default: space.sectionTop, [media.wide]: space.sectionTopWide },
  },
  intro: {
    display: 'flex',
    flexDirection: 'column',
    gap: 16,
  },
  heading: {
    maxWidth: 720,
    color: color.text,
    fontFamily: font.display,
    fontSize: { default: size.s24, [media.wide]: size.s32 },
    fontWeight: 500,
    lineHeight: { default: leading.l32, [media.wide]: leading.l40 },
    letterSpacing: tracking.display,
  },
  muted: {
    color: color.textMuted,
  },
  body: {
    maxWidth: 600,
    color: color.textMuted,
    fontFamily: font.text,
    fontSize: { default: size.s15, [media.wide]: size.s17 },
    lineHeight: { default: leading.l24, [media.wide]: leading.l26 },
  },
  grid: {
    display: 'grid',
    gridTemplateColumns: { default: '1fr', [media.wide]: '1fr 1fr' },
    columnGap: 40,
    rowGap: { default: 48, [media.wide]: 72 },
  },
})
