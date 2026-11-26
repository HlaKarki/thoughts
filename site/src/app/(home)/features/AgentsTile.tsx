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

const tile = features.agents.tile

const typing = stylex.keyframes({
  '0%, 10.444%': { [sequence.typed]: 0, animationTimingFunction: motion.steady },
  '47.258%, 93.995%': { [sequence.typed]: 47, animationTimingFunction: motion.atOnce },
  '94.386%, 100%': { [sequence.typed]: 0 },
})

const cursorWhileTyping = stylex.keyframes({
  '0%': { opacity: 1, animationTimingFunction: motion.atOnce },
  '52.219%, 94.778%': { opacity: 0, animationTimingFunction: motion.easeOut },
  '100%': { opacity: 1 },
})

const printed = stylex.keyframes({
  '0%': { opacity: 0, animationTimingFunction: motion.atOnce },
  '52.219%, 88.773%': { opacity: 1, animationTimingFunction: motion.easeIn },
  '93.995%, 100%': { opacity: 0 },
})

const grow = stylex.keyframes({
  '0%': { gridTemplateRows: '0fr', opacity: 0, animationTimingFunction: motion.atOnce },
  '56.136%, 93.995%': { gridTemplateRows: '1fr', opacity: 1, animationTimingFunction: motion.atOnce },
  '94.386%, 100%': { gridTemplateRows: '0fr', opacity: 0 },
})

const reset = stylex.keyframes({
  '0%, 88.773%': { opacity: 1, animationTimingFunction: motion.easeIn },
  '93.995%, 94.778%': { opacity: 0, animationTimingFunction: motion.easeOut },
  '100%': { opacity: 1 },
})

export function AgentsTile() {
  return (
    <Tile label={tile.label}>
      <MiniWindow title={tile.title} xstyle={styles.window}>
        <div {...stylex.props(styles.session)}>
          <span {...stylex.props(styles.command)}>
            <span {...stylex.props(styles.prompt)}>{tile.prompt}</span>
            <span {...stylex.props(loop.run, styles.loop, styles.resetting)}>
              <TypedText text={tile.command} wrapWords xstyle={[loop.run, styles.loop, styles.typing]} />
            </span>
            <span {...stylex.props(styles.cursor, styles.inlineCursor, loop.run, styles.loop, styles.cursorWhileTyping)} />
          </span>
          <span {...stylex.props(styles.text, loop.run, styles.loop, styles.printing)}>{tile.output}</span>
          <span {...stylex.props(styles.line, styles.row, loop.run, styles.loop, styles.printing)}>
            <span {...stylex.props(styles.text, styles.prompt)}>{tile.prompt}</span>
            <span {...stylex.props(styles.cursor)} />
          </span>
        </div>
      </MiniWindow>
      <MiniPanel xstyle={styles.panel} listXstyle={[loop.run, styles.loop, styles.resetting]}>
        <MiniBarsRow widths={[100, 44]} />
        <MiniBarsRow widths={[88]} />
        <MiniBarsRow widths={[76]} />
        <MiniBarsRow widths={[88]} />
        <MiniBarsRow widths={[100, 44]} />
        <MiniBarsRow widths={[76]} />
        <MiniBarsRow widths={[96, 60]} />
        <MiniBarsRow widths={[88]} />
        <MiniBarsRow widths={[100, 44]} />
        <Collapse element="li" xstyle={[loop.run, styles.loop, styles.growing]}>
          <MiniRow element="div" time={tile.time}>
            {tile.row}
          </MiniRow>
        </Collapse>
      </MiniPanel>
    </Tile>
  )
}

const styles = stylex.create({
  loop: {
    animationDuration: '7660ms',
  },
  resetting: {
    animationName: { default: null, [media.motion]: reset },
  },
  window: {
    top: { default: 16, [media.wide]: 24 },
    left: { default: 16, [media.wide]: 24 },
    width: { default: 158, [media.wide]: 284 },
    height: { default: 368, [media.wide]: 272 },
  },
  session: {
    display: 'flex',
    flexDirection: 'column',
    paddingBlock: 10,
    paddingLeft: 12,
    paddingRight: 8,
  },
  command: {
    color: color.rowText,
    fontFamily: font.mono,
    fontSize: size.s11,
    lineHeight: leading.l16,
  },
  line: {
    display: 'flex',
  },
  row: {
    alignItems: 'center',
    flexShrink: 0,
    height: 16,
  },
  text: {
    color: color.rowText,
    fontFamily: font.mono,
    fontSize: size.s11,
    lineHeight: leading.l16,
    whiteSpace: 'pre',
  },
  prompt: {
    display: 'inline-block',
    color: color.rowTime,
    whiteSpace: 'pre',
  },
  typing: {
    animationName: { default: null, [media.motion]: typing },
  },
  cursor: {
    flexShrink: 0,
    width: 7,
    height: 13,
    backgroundColor: color.cursorBlock,
  },
  inlineCursor: {
    display: 'inline-block',
    verticalAlign: 'top',
    marginTop: 1.5,
    opacity: 0,
  },
  cursorWhileTyping: {
    animationName: { default: null, [media.motion]: cursorWhileTyping },
  },
  printing: {
    animationName: { default: null, [media.motion]: printed },
  },
  panel: {
    top: { default: 16, [media.wide]: 24 },
    left: { default: 182, [media.wide]: 316 },
    width: 160,
    height: { default: 368, [media.wide]: 272 },
  },
  growing: {
    animationName: { default: null, [media.motion]: grow },
  },
})
