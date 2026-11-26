import * as stylex from '@stylexjs/stylex'
import { Collapse } from '@/components/Collapse'
import { MiniBarsRow, MiniPanel, MiniRow } from '@/components/MiniPanel'
import { MiniWindow } from '@/components/MiniWindow'
import { TypedText } from '@/components/TypedText'
import { features } from '@/content/features'
import { loop } from '@/styles/loop'
import { color, font, leading, media, motion, size } from '@/styles/tokens.stylex'
import { sequence } from '@/styles/sequence.stylex'
import { Tile } from './Tile'

const tile = features.markdown.tile

const typing = stylex.keyframes({
  '0%, 9.828%': { [sequence.typed]: 0, animationTimingFunction: motion.steady },
  '53.317%, 94.349%': { [sequence.typed]: 59, animationTimingFunction: motion.atOnce },
  '94.717%, 100%': { [sequence.typed]: 0 },
})

const grow = stylex.keyframes({
  '0%': { gridTemplateRows: '0fr', opacity: 0, animationTimingFunction: motion.atOnce },
  '59.951%, 94.349%': { gridTemplateRows: '1fr', opacity: 1, animationTimingFunction: motion.atOnce },
  '94.717%, 100%': { gridTemplateRows: '0fr', opacity: 0 },
})

const reset = stylex.keyframes({
  '0%, 89.435%': { opacity: 1, animationTimingFunction: motion.easeIn },
  '94.349%, 95.086%': { opacity: 0, animationTimingFunction: motion.easeOut },
  '100%': { opacity: 1 },
})

export function MarkdownTile() {
  return (
    <Tile label={tile.label}>
      <MiniWindow title={tile.fileName} xstyle={styles.window}>
        <div {...stylex.props(styles.file)}>
          <span {...stylex.props(styles.text)}>{tile.frontMatter}</span>
          <span {...stylex.props(styles.text, styles.edited, loop.run, styles.loop, styles.resetting)}>
            <TypedText text={tile.typed} wrapWords xstyle={[loop.run, styles.loop, styles.typing]} />
            <span {...stylex.props(styles.caret)} />
          </span>
        </div>
      </MiniWindow>
      <MiniPanel xstyle={styles.panel} listXstyle={[loop.run, styles.loop, styles.resetting]}>
        <MiniBarsRow widths={[100, 44]} />
        <MiniBarsRow widths={[76]} />
        <MiniRow time={tile.time}>
          <span {...stylex.props(styles.note)}>
            <span>{tile.note}</span>
            <Collapse xstyle={[loop.run, styles.loop, styles.growing]}>
              <span>{tile.typed}</span>
            </Collapse>
          </span>
        </MiniRow>
        <MiniBarsRow widths={[100, 44]} />
      </MiniPanel>
    </Tile>
  )
}

const styles = stylex.create({
  loop: {
    animationDuration: '8140ms',
  },
  resetting: {
    animationName: { default: null, [media.motion]: reset },
  },
  window: {
    top: { default: 16, [media.wide]: 24 },
    left: { default: 16, [media.wide]: 24 },
    width: { default: 300, [media.wide]: 284 },
    height: { default: 300, [media.wide]: 272 },
  },
  file: {
    display: 'flex',
    flexDirection: 'column',
    paddingBlock: 10,
    paddingLeft: 12,
    paddingRight: 8,
  },
  text: {
    color: color.rowText,
    fontFamily: font.mono,
    fontSize: size.s11,
    lineHeight: leading.l16,
    whiteSpace: 'pre',
  },
  edited: {
    maxWidth: { default: 150, [media.wide]: 'none' },
    whiteSpace: 'normal',
  },
  typing: {
    animationName: { default: null, [media.motion]: typing },
  },
  caret: {
    display: 'inline-block',
    verticalAlign: 'top',
    width: 1,
    height: 13,
    marginTop: 1.5,
    marginLeft: 1,
    backgroundColor: color.caret,
  },
  panel: {
    top: { default: 72, [media.wide]: 24 },
    left: { default: 182, [media.wide]: 316 },
    width: 160,
    height: { default: 312, [media.wide]: 272 },
  },
  note: {
    display: 'flex',
    flexDirection: 'column',
  },
  growing: {
    animationName: { default: null, [media.motion]: grow },
  },
})
