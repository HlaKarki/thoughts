import * as stylex from '@stylexjs/stylex'
import { features } from '@/content/features'
import { layout } from '@/styles/layout'
import { media, space } from '@/styles/tokens.stylex'
import { AgentsTile } from './features/AgentsTile'
import { FeatureCard } from './features/FeatureCard'
import { MarkdownTile } from './features/MarkdownTile'
import { PrivacyTile } from './features/PrivacyTile'
import { ScreenshotTile } from './features/ScreenshotTile'
import { SearchTile } from './features/SearchTile'
import { SelectionTile } from './features/SelectionTile'
import { SectionIntro } from './SectionIntro'

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
      <SectionIntro
        heading={
          <>
            {first} <br {...stylex.props(layout.narrowInline)} />
            {second}
          </>
        }
        muted={features.headingMuted}
        body={features.body}
      />
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
  grid: {
    display: 'grid',
    gridTemplateColumns: { default: '1fr', [media.wide]: '1fr 1fr' },
    columnGap: 40,
    rowGap: { default: 48, [media.wide]: 72 },
  },
})
