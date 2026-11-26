import * as stylex from '@stylexjs/stylex'
import { Collapse } from '@/components/Collapse'
import { ClearSearch } from '@/components/Icons'
import { Key } from '@/components/Key'
import { MiniBarsRow, MiniPanel, MiniRow, MiniSearchPlaceholder } from '@/components/MiniPanel'
import { MiniLine, MiniPage } from '@/components/MiniPage'
import { MiniWindow } from '@/components/MiniWindow'
import { TypedText } from '@/components/TypedText'
import { features } from '@/content/features'
import { type BoldWindow, typedBold } from '@/lib/searchHighlight'
import { loop } from '@/styles/loop'
import { color, font, leading, media, motion, radius, size } from '@/styles/tokens.stylex'
import { sequence } from '@/styles/sequence.stylex'
import { Tile } from './Tile'

const tile = features.search.tile
const shot = tile.screenshot

const typing = stylex.keyframes({
  '0%, 21.83%': { [sequence.typed]: 0, animationTimingFunction: motion.steady },
  '32.96%': { [sequence.typed]: 9, animationTimingFunction: motion.atOnce },
  '72.63%, 100%': { [sequence.typed]: 0 },
})

const searchFocus = stylex.keyframes({
  '0%': { opacity: 0, animationTimingFunction: motion.atOnce },
  '16.158%': { opacity: 1, animationTimingFunction: motion.atOnce },
  '72.63%, 100%': { opacity: 0 },
})

const composerFocus = stylex.keyframes({
  '0%': { opacity: 1, animationTimingFunction: motion.atOnce },
  '16.158%': { opacity: 0, animationTimingFunction: motion.atOnce },
  '72.63%, 100%': { opacity: 1 },
})

const sourcesShown = stylex.keyframes({
  '0%': { gridTemplateRows: '0fr', opacity: 0, animationTimingFunction: motion.atOnce },
  '23.083%': { gridTemplateRows: '1fr', opacity: 1, animationTimingFunction: motion.atOnce },
  '72.63%, 100%': { gridTemplateRows: '0fr', opacity: 0 },
})

const imageTextShown = stylex.keyframes({
  '0%': { gridTemplateRows: '0fr', opacity: 0, animationTimingFunction: motion.atOnce },
  '33.059%': { gridTemplateRows: '1fr', opacity: 1, animationTimingFunction: motion.atOnce },
  '72.63%, 100%': { gridTemplateRows: '0fr', opacity: 0 },
})

const narrowed = stylex.keyframes({
  '0%': { gridTemplateRows: '1fr', opacity: 1, marginTop: 0, animationTimingFunction: motion.atOnce },
  '33.059%': { gridTemplateRows: '0fr', opacity: 0, marginTop: -2, animationTimingFunction: motion.atOnce },
  '72.63%, 100%': { gridTemplateRows: '1fr', opacity: 1, marginTop: 0 },
})

const findKeysShown = stylex.keyframes({
  '0%, 46.167%': { opacity: 1, animationTimingFunction: motion.easeIn },
  '52.762%, 93.405%': { opacity: 0, animationTimingFunction: motion.easeOut },
  '100%': { opacity: 1 },
})

const clearKeyShown = stylex.keyframes({
  '0%, 53.092%': { opacity: 0, animationTimingFunction: motion.easeOut },
  '59.687%, 86.48%': { opacity: 1, animationTimingFunction: motion.easeIn },
  '93.075%, 100%': { opacity: 0 },
})

const pressCommand = stylex.keyframes({
  '0%, 13.19%': { borderColor: color.keyBorder, translate: '0 0', animationTimingFunction: motion.easeInOut },
  '14.18%, 18.137%': { borderColor: color.accent, translate: '0 1px', animationTimingFunction: motion.easeInOut },
  '19.456%, 100%': { borderColor: color.keyBorder, translate: '0 0' },
})

const pressF = stylex.keyframes({
  '0%, 15.169%': { borderColor: color.keyBorder, translate: '0 0', animationTimingFunction: motion.easeInOut },
  '16.158%, 17.148%': { borderColor: color.accent, translate: '0 1px', animationTimingFunction: motion.easeInOut },
  '18.467%, 100%': { borderColor: color.keyBorder, translate: '0 0' },
})

const pressEscape = stylex.keyframes({
  '0%, 71.641%': { borderColor: color.keyBorder, translate: '0 0', animationTimingFunction: motion.easeInOut },
  '72.63%, 73.619%': { borderColor: color.accent, translate: '0 1px', animationTimingFunction: motion.easeInOut },
  '74.938%, 100%': { borderColor: color.keyBorder, translate: '0 0' },
})

function typedPast(length: number): string {
  return `clamp(0, (${sequence.typed} - ${length}) * 1000, 1)`
}

function weightOf(windows: ReadonlyArray<BoldWindow>): string {
  const steps = windows.map(({ from, to }) => (to === null ? typedPast(from) : `${typedPast(from)} - ${typedPast(to)}`))
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

function Notice() {
  return (
    <span {...stylex.props(styles.thumbnail)}>
      <span {...stylex.props(styles.notice)}>
        <span {...stylex.props(styles.noticeEyebrow)}>{shot.eyebrow}</span>
        <span {...stylex.props(styles.noticeHeading)}>{shot.heading}</span>
        <span {...stylex.props(styles.noticeBody)}>{shot.body}</span>
      </span>
    </span>
  )
}

export function SearchTile() {
  const run = [loop.run, styles.loop]
  return (
    <Tile label={tile.label}>
      <div {...stylex.props(styles.stack)}>
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
        <div {...stylex.props(styles.keys)}>
          <div {...stylex.props(styles.keyGroup, run, styles.findKeys)}>
            <Key xstyle={[run, styles.pressingCommand]}>{tile.findKeys[0]}</Key>
            <Key xstyle={[run, styles.pressingF]}>{tile.findKeys[1]}</Key>
          </div>
          <div {...stylex.props(styles.keyGroup, styles.clearGroup, run, styles.clearKey)}>
            <Key xstyle={[styles.escape, run, styles.pressingEscape]}>{tile.clearKey}</Key>
          </div>
        </div>
      </div>
      <MiniPanel
        xstyle={[styles.panel, run, styles.typing]}
        composerCaretXstyle={[styles.composerCaret, run, styles.composerFocusing]}
        search={
          <>
            <span {...stylex.props(styles.query)}>
              <span {...stylex.props(styles.queryText)}>
                <TypedText text={tile.query} />
              </span>
              <span {...stylex.props(styles.caret, run, styles.searchFocusing)} />
              <MiniSearchPlaceholder xstyle={styles.placeholder} />
            </span>
            <ClearSearch size={9} xstyle={styles.clear} />
          </>
        }
      >
        <Collapse element="li" xstyle={[styles.narrowed, run, styles.narrowing]}>
          <MiniBarsRow element="div" widths={[100, 44]} />
        </Collapse>
        <MiniRow time={tile.message.time}>
          <span>
            <Highlighted text={tile.message.text} />
          </span>
          <Collapse xstyle={[run, styles.revealing]}>
            <span {...stylex.props(styles.source)}>
              <Highlighted text={tile.message.source} />
            </span>
          </Collapse>
        </MiniRow>
        <MiniRow time={shot.time}>
          <Notice />
          <Collapse xstyle={[run, styles.revealing]}>
            <span {...stylex.props(styles.source)}>
              <Highlighted text={shot.source} />
            </span>
          </Collapse>
          <Collapse xstyle={[styles.oneLine, run, styles.imageTextRevealing]}>
            <span {...stylex.props(styles.source, styles.imageText)}>
              {`${shot.imageText}: "`}
              <Highlighted text={shot.excerpt} />
              {'"'}
            </span>
          </Collapse>
        </MiniRow>
        <Collapse element="li" xstyle={[styles.narrowed, run, styles.narrowing]}>
          <MiniRow element="div" time={tile.newest.time}>
            <span>
              <Highlighted text={tile.newest.text} />
            </span>
          </MiniRow>
        </Collapse>
      </MiniPanel>
    </Tile>
  )
}

const styles = stylex.create({
  loop: {
    animationDuration: '6065ms',
  },
  stack: {
    position: 'absolute',
    top: { default: 40, [media.wide]: 24 },
    left: { default: 16, [media.wide]: 24 },
    display: 'flex',
    flexDirection: 'column',
    alignItems: 'start',
    width: 264,
  },
  window: {
    position: 'relative',
    width: '100%',
  },
  keys: {
    position: 'relative',
    marginTop: 12,
  },
  keyGroup: {
    display: 'flex',
    gap: 6,
  },
  findKeys: {
    animationName: { default: null, [media.motion]: findKeysShown },
  },
  clearGroup: {
    position: 'absolute',
    top: 0,
    left: 0,
    opacity: 0,
  },
  clearKey: {
    animationName: { default: null, [media.motion]: clearKeyShown },
  },
  escape: {
    width: 40,
    fontSize: size.s12,
  },
  pressingCommand: {
    animationName: { default: null, [media.motion]: pressCommand },
  },
  pressingF: {
    animationName: { default: null, [media.motion]: pressF },
  },
  pressingEscape: {
    animationName: { default: null, [media.motion]: pressEscape },
  },
  panel: {
    top: { default: 64, [media.wide]: 24 },
    left: { default: 92, [media.wide]: 200 },
    width: { default: 250, [media.wide]: 276 },
    height: { default: 320, [media.wide]: 272 },
  },
  typing: {
    animationName: { default: null, [media.motion]: typing },
  },
  query: {
    display: 'flex',
    alignItems: 'center',
    flexGrow: 1,
    gap: 1,
    minWidth: 0,
  },
  queryText: {
    color: color.rowText,
    fontFamily: font.text,
    fontSize: size.s12,
    lineHeight: leading.l16,
    whiteSpace: 'nowrap',
  },
  caret: {
    flexShrink: 0,
    width: 1,
    height: 12,
    backgroundColor: color.caret,
  },
  searchFocusing: {
    animationName: { default: null, [media.motion]: searchFocus },
  },
  composerCaret: {
    opacity: 0,
  },
  composerFocusing: {
    animationName: { default: null, [media.motion]: composerFocus },
  },
  placeholder: {
    opacity: `calc(1 - clamp(0, (${sequence.typed} - 1) * 1000, 1))`,
  },
  clear: {
    marginRight: 7,
    color: color.fieldIcon,
    opacity: `clamp(0, (${sequence.typed} - 1) * 1000, 1)`,
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
    animationName: { default: null, [media.motion]: sourcesShown },
  },
  imageTextRevealing: {
    animationName: { default: null, [media.motion]: imageTextShown },
  },
  oneLine: {
    gridTemplateColumns: 'minmax(0, 1fr)',
  },
  weight: (fontWeight: string) => ({
    fontWeight,
  }),
  source: {
    paddingTop: 2,
    color: color.rowTime,
    whiteSpace: 'pre',
  },
  imageText: {
    overflow: 'hidden',
    textOverflow: 'ellipsis',
  },
  thumbnail: {
    position: 'relative',
    display: 'block',
    flexShrink: 0,
    width: 126,
    height: 70,
    overflow: 'clip',
    borderRadius: radius.r6,
    borderWidth: 1,
    borderStyle: 'solid',
    borderColor: color.thumbBorder,
    backgroundColor: color.notice,
  },
  notice: {
    position: 'absolute',
    top: 0,
    left: 0,
    display: 'flex',
    flexDirection: 'column',
    width: 248,
    height: 136,
    paddingBlock: 16,
    paddingInline: 18,
    fontFamily: font.text,
    transform: 'scale(0.5)',
    transformOrigin: '0 0',
  },
  noticeEyebrow: {
    color: color.noticeEyebrow,
    fontSize: 10,
    fontWeight: 600,
    letterSpacing: '0.06em',
    lineHeight: '12px',
    textTransform: 'uppercase',
  },
  noticeHeading: {
    marginTop: 5,
    color: color.noticeHeading,
    fontSize: 21,
    fontWeight: 700,
    lineHeight: '26px',
  },
  noticeBody: {
    marginTop: 6,
    color: color.noticeBody,
    fontSize: 12,
    lineHeight: '17px',
  },
})
