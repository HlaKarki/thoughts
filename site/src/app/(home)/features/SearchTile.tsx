import * as stylex from '@stylexjs/stylex'
import { Collapse } from '@/components/Collapse'
import { MiniBarsRow, MiniPanel, MiniRow } from '@/components/MiniPanel'
import { MiniLine, MiniPage } from '@/components/MiniPage'
import { MiniWindow } from '@/components/MiniWindow'
import { TypedText } from '@/components/TypedText'
import { features } from '@/content/features'
import type { Rich } from '@/content/types'
import { loop } from '@/styles/loop'
import { color, font, leading, media, size } from '@/styles/tokens.stylex'
import { sequence } from '@/styles/sequence.stylex'
import { Tile } from './Tile'

const tile = features.search.tile

const typing = stylex.keyframes({
  '0%': { opacity: 1, [sequence.typed]: 9 },
  '4%': { opacity: 0, [sequence.typed]: 9 },
  '4.01%, 11%': { opacity: 1, [sequence.typed]: 0 },
  '20%, 100%': { opacity: 1, [sequence.typed]: 9 },
})

const narrowed = stylex.keyframes({
  '0%': { gridTemplateRows: '0fr', opacity: 0, marginTop: -2 },
  '4%, 23%': { gridTemplateRows: '1fr', opacity: 1, marginTop: 0 },
  '27%, 100%': { gridTemplateRows: '0fr', opacity: 0, marginTop: -2 },
})

const revealed = stylex.keyframes({
  '0%': { gridTemplateRows: '1fr', opacity: 1 },
  '4%, 23%': { gridTemplateRows: '0fr', opacity: 0 },
  '27%, 100%': { gridTemplateRows: '1fr', opacity: 1 },
})

const matched = stylex.keyframes({
  '0%, 4%': { fontWeight: '600' },
  '4.01%, 19.99%': { fontWeight: '400' },
  '20%, 100%': { fontWeight: '600' },
})

function Highlighted({ text }: { readonly text: Rich }) {
  return (
    <>
      {text.map((part, index) =>
        typeof part === 'string' ? (
          part
        ) : 'strong' in part ? (
          <strong key={index} {...stylex.props(styles.match, loop.short, styles.matching)}>
            {part.strong}
          </strong>
        ) : null,
      )}
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
        xstyle={styles.panel}
        search={
          <span {...stylex.props(styles.query)}>
            <span {...stylex.props(styles.queryText)}>
              <TypedText text={tile.query} xstyle={[loop.short, styles.typing]} />
            </span>
            <span {...stylex.props(styles.caret)} />
          </span>
        }
      >
        <Collapse element="li" xstyle={[styles.narrowed, loop.short, styles.narrowing]}>
          <MiniBarsRow element="div" widths={[100, 44]} />
        </Collapse>
        {tile.matches.map((match, index) => (
          <MiniRow key={index} time={match.time}>
            <span>
              <Highlighted text={match.text} />
            </span>
            <Collapse xstyle={[loop.short, styles.revealing]}>
              <span {...stylex.props(styles.source)}>{match.source}</span>
            </Collapse>
          </MiniRow>
        ))}
        <Collapse element="li" xstyle={[styles.narrowed, loop.short, styles.narrowing]}>
          <MiniRow element="div" time={tile.newest.time}>
            {tile.newest.text}
          </MiniRow>
        </Collapse>
      </MiniPanel>
    </Tile>
  )
}

const styles = stylex.create({
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
  match: {
    fontWeight: 600,
  },
  matching: {
    animationName: { default: null, [media.motion]: matched },
  },
  source: {
    paddingTop: 2,
    color: color.rowTime,
    whiteSpace: 'pre',
  },
})
