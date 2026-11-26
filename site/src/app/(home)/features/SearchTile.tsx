import * as stylex from '@stylexjs/stylex'
import { Collapse } from '@/components/Collapse'
import { MiniBarsRow, MiniPanel, MiniRow } from '@/components/MiniPanel'
import { MiniLine, MiniPage } from '@/components/MiniPage'
import { MiniWindow } from '@/components/MiniWindow'
import { TypedText } from '@/components/TypedText'
import { features } from '@/content/features'
import { type BoldWindow, typedBold } from '@/lib/searchHighlight'
import { loop } from '@/styles/loop'
import { color, font, leading, media, motion, size } from '@/styles/tokens.stylex'
import { sequence } from '@/styles/sequence.stylex'
import { Tile } from './Tile'

const tile = features.search.tile

const typing = stylex.keyframes({
  '0%, 15.541%': { [sequence.typed]: 0, animationTimingFunction: motion.steady },
  '30.011%, 90.139%': { [sequence.typed]: 9, animationTimingFunction: motion.atOnce },
  '90.782%, 100%': { [sequence.typed]: 0 },
})

const revealed = stylex.keyframes({
  '0%': { gridTemplateRows: '0fr', opacity: 0, animationTimingFunction: motion.atOnce },
  '17.149%, 90.139%': { gridTemplateRows: '1fr', opacity: 1, animationTimingFunction: motion.atOnce },
  '90.782%, 100%': { gridTemplateRows: '0fr', opacity: 0 },
})

const narrowed = stylex.keyframes({
  '0%': { gridTemplateRows: '1fr', opacity: 1, marginTop: 0, animationTimingFunction: motion.atOnce },
  '30.118%, 90.139%': { gridTemplateRows: '0fr', opacity: 0, marginTop: -2, animationTimingFunction: motion.atOnce },
  '90.782%, 100%': { gridTemplateRows: '1fr', opacity: 1, marginTop: 0 },
})

const reset = stylex.keyframes({
  '0%, 81.565%': { opacity: 1, animationTimingFunction: motion.easeIn },
  '90.139%, 91.426%': { opacity: 0, animationTimingFunction: motion.easeOut },
  '100%': { opacity: 1 },
})

function weightOf(windows: ReadonlyArray<BoldWindow>): string {
  const after = (length: number) => `clamp(0, (${sequence.typed} - ${length}) * 1000, 1)`
  const steps = windows.map(({ from, to }) => (to === null ? after(from) : `${after(from)} - ${after(to)}`))
  return `calc(400 + 200 * (${steps.join(' + ')}))`
}

function Highlighted({ text }: { readonly text: string }) {
  return (
    <>
      {typedBold(text, tile.query).map((segment, index) => (
        <span key={index} {...stylex.props(segment.windows.length > 0 && styles.weight(weightOf(segment.windows)))}>
          {segment.text}
        </span>
      ))}
    </>
  )
}

export function SearchTile() {
  return (
    <Tile label={tile.label}>
      <MiniWindow address xstyle={styles.window}>
        <MiniPage>
          <MiniLine width={212} />
          <MiniLine width={196} />
          <MiniLine width={206} />
          <MiniLine width={150} />
          <MiniLine width={0} />
          <MiniLine width={204} />
          <MiniLine width={188} />
          <MiniLine width={120} />
        </MiniPage>
      </MiniWindow>
      <MiniPanel
        xstyle={[styles.panel, loop.run, styles.loop, styles.typing]}
        listXstyle={[loop.run, styles.loop, styles.resetting]}
        search={
          <span {...stylex.props(styles.query, loop.run, styles.loop, styles.resetting)}>
            <span {...stylex.props(styles.queryText)}>
              <TypedText text={tile.query} />
            </span>
            <span {...stylex.props(styles.caret)} />
          </span>
        }
      >
        <Collapse element="li" xstyle={[styles.narrowed, loop.run, styles.loop, styles.narrowing]}>
          <MiniBarsRow element="div" widths={[100, 44]} />
        </Collapse>
        {tile.matches.map((match, index) => (
          <MiniRow key={index} time={match.time}>
            <span>
              <Highlighted text={match.text} />
            </span>
            <Collapse xstyle={[loop.run, styles.loop, styles.revealing]}>
              <span {...stylex.props(styles.source)}>
                <Highlighted text={match.source} />
              </span>
            </Collapse>
          </MiniRow>
        ))}
        <Collapse element="li" xstyle={[styles.narrowed, loop.run, styles.loop, styles.narrowing]}>
          <MiniRow element="div" time={tile.newest.time}>
            <Highlighted text={tile.newest.text} />
          </MiniRow>
        </Collapse>
      </MiniPanel>
    </Tile>
  )
}

const styles = stylex.create({
  loop: {
    animationDuration: '4665ms',
  },
  resetting: {
    animationName: { default: null, [media.motion]: reset },
  },
  window: {
    top: { default: 40, [media.wide]: 24 },
    left: { default: 16, [media.wide]: 24 },
    width: 264,
  },
  panel: {
    top: { default: 64, [media.wide]: 24 },
    left: { default: 66, [media.wide]: 200 },
    width: 276,
    height: { default: 320, [media.wide]: 272 },
  },
  query: {
    display: 'flex',
    alignItems: 'center',
    gap: 1,
  },
  queryText: {
    color: color.rowText,
    fontFamily: font.text,
    fontSize: size.s12,
    lineHeight: leading.l16,
    whiteSpace: 'nowrap',
  },
  typing: {
    animationName: { default: null, [media.motion]: typing },
  },
  caret: {
    flexShrink: 0,
    width: 1,
    height: 12,
    backgroundColor: color.caret,
  },
  narrowed: {
    gridTemplateRows: '0fr',
    marginTop: -2,
    opacity: 0,
  },
  narrowing: {
    animationName: { default: null, [media.motion]: narrowed },
  },
  revealing: {
    animationName: { default: null, [media.motion]: revealed },
  },
  weight: (fontWeight: string) => ({
    fontWeight,
  }),
  source: {
    paddingTop: 2,
    color: color.rowTime,
    whiteSpace: 'pre',
  },
})
