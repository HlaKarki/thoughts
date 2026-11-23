import * as stylex from '@stylexjs/stylex'
import { Collapse } from '@/components/Collapse'
import { MiniBarsRow, MiniPanel, MiniRow } from '@/components/MiniPanel'
import { MiniWindow } from '@/components/MiniWindow'
import { features } from '@/content/features'
import { layout } from '@/styles/layout'
import { loop } from '@/styles/loop'
import { color, font, leading, media, size } from '@/styles/tokens.stylex'
import { Tile } from './Tile'

const tile = features.agents.tile
const [firstLine, secondLine] = tile.commandNarrow

const typeCommand = stylex.keyframes({
  '0%': { opacity: 1, maxWidth: '36ch' },
  '4%': { opacity: 0, maxWidth: '36ch' },
  '4.01%, 9%': { opacity: 1, maxWidth: '0ch', animationTimingFunction: 'steps(36, end)' },
  '26%, 100%': { opacity: 1, maxWidth: '36ch' },
})

const typeFirstLine = stylex.keyframes({
  '0%': { opacity: 1, maxWidth: '18ch' },
  '4%': { opacity: 0, maxWidth: '18ch' },
  '4.01%, 9%': { opacity: 1, maxWidth: '0ch', animationTimingFunction: 'steps(18, end)' },
  '17.5%, 100%': { opacity: 1, maxWidth: '18ch' },
})

const typeSecondLine = stylex.keyframes({
  '0%': { opacity: 1, maxWidth: '18ch' },
  '4%': { opacity: 0, maxWidth: '18ch' },
  '4.01%, 17.5%': { opacity: 1, maxWidth: '0ch', animationTimingFunction: 'steps(18, end)' },
  '26%, 100%': { opacity: 1, maxWidth: '18ch' },
})

const cursorWhileTyping = stylex.keyframes({
  '0%, 4%': { opacity: 0 },
  '4.01%, 28.99%': { opacity: 1 },
  '29%, 100%': { opacity: 0 },
})

const cursorFirstLine = stylex.keyframes({
  '0%, 4%': { opacity: 0 },
  '4.01%, 17.49%': { opacity: 1 },
  '17.5%, 100%': { opacity: 0 },
})

const cursorSecondLine = stylex.keyframes({
  '0%, 17.49%': { opacity: 0 },
  '17.5%, 28.99%': { opacity: 1 },
  '29%, 100%': { opacity: 0 },
})

const printed = stylex.keyframes({
  '0%': { opacity: 1 },
  '4%, 28.99%': { opacity: 0 },
  '29%, 100%': { opacity: 1 },
})

const grow = stylex.keyframes({
  '0%': { gridTemplateRows: '1fr', opacity: 1 },
  '4%': { gridTemplateRows: '1fr', opacity: 0 },
  '4.01%, 31%': { gridTemplateRows: '0fr', opacity: 0 },
  '34%, 100%': { gridTemplateRows: '1fr', opacity: 1 },
})

export function AgentsTile() {
  return (
    <Tile label={tile.label}>
      <MiniWindow title={tile.title} xstyle={styles.window}>
        <div {...stylex.props(styles.session)}>
          <span {...stylex.props(layout.wideFlex, styles.row)}>
            <span {...stylex.props(styles.text, styles.prompt)}>{tile.prompt}</span>
            <span {...stylex.props(styles.text, styles.typed, loop.short, styles.typeCommand)}>{tile.command}</span>
            <span {...stylex.props(styles.cursor, styles.typingCursor, loop.short, styles.cursorWhileTyping)} />
          </span>
          <span {...stylex.props(layout.narrowFlex, styles.lines)}>
            <span {...stylex.props(styles.line, styles.row)}>
              <span {...stylex.props(styles.text, styles.prompt)}>{tile.prompt}</span>
              <span {...stylex.props(styles.text, styles.typed, loop.short, styles.typeFirstLine)}>{firstLine}</span>
              <span {...stylex.props(styles.cursor, styles.typingCursor, loop.short, styles.cursorFirstLine)} />
            </span>
            <span {...stylex.props(styles.line, styles.row)}>
              <span {...stylex.props(styles.text, styles.typed, loop.short, styles.typeSecondLine)}>{secondLine}</span>
              <span {...stylex.props(styles.cursor, styles.typingCursor, loop.short, styles.cursorSecondLine)} />
            </span>
          </span>
          <span {...stylex.props(styles.text, loop.short, styles.printing)}>{tile.output}</span>
          <span {...stylex.props(styles.line, styles.row, loop.short, styles.printing)}>
            <span {...stylex.props(styles.text, styles.prompt)}>{tile.prompt}</span>
            <span {...stylex.props(styles.cursor)} />
          </span>
        </div>
      </MiniWindow>
      <MiniPanel xstyle={styles.panel}>
        <MiniBarsRow widths={[100, 44]} />
        <MiniBarsRow widths={[88]} />
        <MiniBarsRow widths={[76]} />
        <MiniBarsRow widths={[88]} />
        <MiniBarsRow widths={[100, 44]} />
        <MiniBarsRow widths={[76]} />
        <MiniBarsRow widths={[96, 60]} />
        <MiniBarsRow widths={[88]} />
        <MiniBarsRow widths={[100, 44]} />
        <Collapse element="li" xstyle={[loop.short, styles.growing]}>
          <MiniRow element="div" time={tile.time}>
            {tile.row}
          </MiniRow>
        </Collapse>
      </MiniPanel>
    </Tile>
  )
}

const styles = stylex.create({
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
  lines: {
    flexDirection: 'column',
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
    color: color.rowTime,
  },
  typed: {
    overflow: 'clip',
  },
  typeCommand: {
    animationName: { default: null, [media.motion]: typeCommand },
  },
  typeFirstLine: {
    animationName: { default: null, [media.motion]: typeFirstLine },
  },
  typeSecondLine: {
    animationName: { default: null, [media.motion]: typeSecondLine },
  },
  cursor: {
    flexShrink: 0,
    width: 7,
    height: 13,
    backgroundColor: color.cursorBlock,
  },
  typingCursor: {
    opacity: 0,
  },
  cursorWhileTyping: {
    animationName: { default: null, [media.motion]: cursorWhileTyping },
  },
  cursorFirstLine: {
    animationName: { default: null, [media.motion]: cursorFirstLine },
  },
  cursorSecondLine: {
    animationName: { default: null, [media.motion]: cursorSecondLine },
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
