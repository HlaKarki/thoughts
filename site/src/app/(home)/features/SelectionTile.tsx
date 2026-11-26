import * as stylex from '@stylexjs/stylex'
import { SavedChip } from '@/components/Chip'
import { MiniBarsRow, MiniPanel, MiniRow } from '@/components/MiniPanel'
import { MiniLine, MiniPage, MiniSelection } from '@/components/MiniPage'
import { MiniWindow } from '@/components/MiniWindow'
import { features } from '@/content/features'
import { layout } from '@/styles/layout'
import { loop } from '@/styles/loop'
import { color, font, leading, media, motion, radius, size } from '@/styles/tokens.stylex'
import { Tile } from './Tile'

const tile = features.selection.tile

const sweep = stylex.keyframes({
  '0%, 8.457%': { opacity: 1, backgroundSize: '0% 100%', animationTimingFunction: motion.easeInOut },
  '17.97%, 90.909%': { opacity: 1, backgroundSize: '100% 100%', animationTimingFunction: motion.easeIn },
  '95.137%': { opacity: 0, backgroundSize: '100% 100%', animationTimingFunction: motion.atOnce },
  '95.455%, 100%': { opacity: 1, backgroundSize: '0% 100%' },
})

const pressFirst = stylex.keyframes({
  '0%, 24.313%': { borderColor: color.keyBorder, translate: '0 0', animationTimingFunction: motion.easeInOut },
  '24.947%, 25.581%': { borderColor: color.accent, translate: '0 1px', animationTimingFunction: motion.easeInOut },
  '26.427%, 100%': { borderColor: color.keyBorder, translate: '0 0' },
})

const pressSecond = stylex.keyframes({
  '0%, 27.484%': { borderColor: color.keyBorder, translate: '0 0', animationTimingFunction: motion.easeInOut },
  '28.118%, 28.753%': { borderColor: color.accent, translate: '0 1px', animationTimingFunction: motion.easeInOut },
  '29.598%, 100%': { borderColor: color.keyBorder, translate: '0 0' },
})

const savedChip = stylex.keyframes({
  '0%, 30.444%': { opacity: 0, translate: '24px 0', animationTimingFunction: motion.appEaseOut },
  '32.558%, 55.814%': { opacity: 1, translate: '0 0', animationTimingFunction: motion.appEaseOut },
  '57.928%, 100%': { opacity: 0, translate: '24px 0' },
})

const panelShown = stylex.keyframes({
  '0%': { opacity: 0, animationTimingFunction: motion.atOnce },
  '65.539%, 90.909%': { opacity: 1, animationTimingFunction: motion.easeIn },
  '95.137%, 100%': { opacity: 0 },
})

function Selection() {
  return (
    <MiniSelection
      text={tile.row}
      xstyle={styles.measure}
      linesXstyle={styles.roomForLines}
      highlightXstyle={[loop.run, styles.loop, styles.sweeping]}
    />
  )
}

export function SelectionTile() {
  return (
    <Tile label={tile.label}>
      <div {...stylex.props(styles.stack)}>
        <MiniWindow address xstyle={styles.window} addressXstyle={styles.address}>
          <MiniPage code compactWhenNarrow>
            <span {...stylex.props(layout.wideFlex, styles.lines)}>
              <MiniLine width={212} />
              <Selection />
              <MiniLine width={150} />
            </span>
            <span {...stylex.props(layout.narrowFlex, styles.lines)}>
              <MiniLine width={120} />
              <Selection />
              <MiniLine width={96} />
            </span>
          </MiniPage>
        </MiniWindow>
        <div {...stylex.props(styles.keys)}>
          <kbd {...stylex.props(styles.key, loop.run, styles.loop, styles.pressFirst)}>{tile.key}</kbd>
          <kbd {...stylex.props(styles.key, loop.run, styles.loop, styles.pressSecond)}>{tile.key}</kbd>
        </div>
      </div>
      <MiniPanel xstyle={[styles.panel, loop.run, styles.loop, styles.panelShown]}>
        <MiniBarsRow widths={[76]} xstyle={layout.narrowFlex} />
        <MiniBarsRow widths={[88]} xstyle={layout.narrowFlex} />
        <MiniBarsRow widths={[100, 44]} xstyle={layout.narrowFlex} />
        <MiniBarsRow widths={[88]} />
        <MiniBarsRow widths={[70]} dim />
        <MiniBarsRow widths={[88]} />
        <MiniBarsRow widths={[100, 44]} />
        <MiniBarsRow widths={[76]} />
        <MiniRow time={tile.time}>{tile.row}</MiniRow>
      </MiniPanel>
      <SavedChip title={tile.saved} message={tile.row} xstyle={[styles.chip, loop.run, styles.loop, styles.chipIn]} />
    </Tile>
  )
}

const styles = stylex.create({
  loop: {
    animationDuration: '9460ms',
  },
  stack: {
    position: 'absolute',
    top: { default: 41, [media.wide]: 24 },
    left: { default: 16, [media.wide]: 24 },
    display: 'flex',
    flexDirection: 'column',
    alignItems: 'start',
    width: { default: 158, [media.wide]: 264 },
  },
  window: {
    position: 'relative',
    width: '100%',
  },
  address: {
    left: { default: 48, [media.wide]: 84 },
  },
  lines: {
    flexDirection: 'column',
  },
  measure: {
    maxWidth: { default: 134, [media.wide]: 200 },
  },
  roomForLines: {
    WebkitLineClamp: { default: 4, [media.wide]: 2 },
  },
  sweeping: {
    animationName: { default: null, [media.motion]: sweep },
  },
  keys: {
    position: 'relative',
    marginTop: { default: -7, [media.wide]: 11 },
    display: 'flex',
    gap: 6,
  },
  key: {
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'center',
    width: 28,
    height: 28,
    borderRadius: radius.r6,
    borderWidth: 1,
    borderStyle: 'solid',
    borderColor: color.keyBorder,
    backgroundColor: color.key,
    boxShadow: color.keyShadow,
    color: color.keyText,
    fontFamily: font.text,
    fontSize: size.s14,
    lineHeight: leading.l16,
  },
  pressFirst: {
    animationName: { default: null, [media.motion]: pressFirst },
  },
  pressSecond: {
    animationName: { default: null, [media.motion]: pressSecond },
  },
  panel: {
    top: { default: 16, [media.wide]: 24 },
    left: { default: 182, [media.wide]: 316 },
    width: 160,
    height: { default: 368, [media.wide]: 272 },
  },
  panelShown: {
    animationName: { default: null, [media.motion]: panelShown },
  },
  chip: {
    top: { default: 324, [media.wide]: 236 },
    left: { default: 42, [media.wide]: 176 },
    opacity: 0,
  },
  chipIn: {
    animationName: { default: null, [media.motion]: savedChip },
  },
})
