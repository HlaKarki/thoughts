import * as stylex from '@stylexjs/stylex'
import { SavedChip } from '@/components/Chip'
import { Key } from '@/components/Key'
import { MiniBarsRow, MiniPanel, MiniRow } from '@/components/MiniPanel'
import { MiniLine, MiniPage, MiniSelection } from '@/components/MiniPage'
import { MiniWindow } from '@/components/MiniWindow'
import { features } from '@/content/features'
import { layout } from '@/styles/layout'
import { loop } from '@/styles/loop'
import { color, media, motion } from '@/styles/tokens.stylex'
import { Tile } from './Tile'

const tile = features.selection.tile

const sweep = stylex.keyframes({
  '0%, 7.968%': { opacity: 1, backgroundSize: '0% 100%', animationTimingFunction: motion.easeInOut },
  '16.932%, 91.434%': { opacity: 1, backgroundSize: '100% 100%', animationTimingFunction: motion.easeIn },
  '95.418%': { opacity: 0, backgroundSize: '100% 100%', animationTimingFunction: motion.atOnce },
  '95.717%, 100%': { opacity: 1, backgroundSize: '0% 100%' },
})

const pressFirst = stylex.keyframes({
  '0%, 22.908%': { borderColor: color.keyBorder, translate: '0 0', animationTimingFunction: motion.easeInOut },
  '23.506%, 24.104%': { borderColor: color.accent, translate: '0 1px', animationTimingFunction: motion.easeInOut },
  '24.9%, 100%': { borderColor: color.keyBorder, translate: '0 0' },
})

const pressSecond = stylex.keyframes({
  '0%, 25.896%': { borderColor: color.keyBorder, translate: '0 0', animationTimingFunction: motion.easeInOut },
  '26.494%, 27.092%': { borderColor: color.accent, translate: '0 1px', animationTimingFunction: motion.easeInOut },
  '27.888%, 100%': { borderColor: color.keyBorder, translate: '0 0' },
})

const savedChip = stylex.keyframes({
  '0%, 28.685%': { opacity: 0, translate: '24px 0', animationTimingFunction: motion.appEaseOut },
  '30.677%, 52.59%': { opacity: 1, translate: '0 0', animationTimingFunction: motion.appEaseOut },
  '54.582%, 100%': { opacity: 0, translate: '24px 0' },
})

const shiftKeysShown = stylex.keyframes({
  '0%, 54.582%': { opacity: 1, animationTimingFunction: motion.easeIn },
  '58.566%, 96.016%': { opacity: 0, animationTimingFunction: motion.easeOut },
  '100%': { opacity: 1 },
})

const summonKeysShown = stylex.keyframes({
  '0%, 58.765%': { opacity: 0, animationTimingFunction: motion.easeOut },
  '62.749%, 91.434%': { opacity: 1, animationTimingFunction: motion.easeIn },
  '95.418%, 100%': { opacity: 0 },
})

const pressOption = stylex.keyframes({
  '0%, 65.737%': { borderColor: color.keyBorder, translate: '0 0', animationTimingFunction: motion.easeInOut },
  '66.335%, 68.725%': { borderColor: color.accent, translate: '0 1px', animationTimingFunction: motion.easeInOut },
  '69.522%, 100%': { borderColor: color.keyBorder, translate: '0 0' },
})

const pressN = stylex.keyframes({
  '0%, 66.932%': { borderColor: color.keyBorder, translate: '0 0', animationTimingFunction: motion.easeInOut },
  '67.53%, 68.127%': { borderColor: color.accent, translate: '0 1px', animationTimingFunction: motion.easeInOut },
  '68.924%, 100%': { borderColor: color.keyBorder, translate: '0 0' },
})

const panelShown = stylex.keyframes({
  '0%': { opacity: 0, animationTimingFunction: motion.atOnce },
  '67.53%, 91.434%': { opacity: 1, animationTimingFunction: motion.easeIn },
  '95.418%, 100%': { opacity: 0 },
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
          <div {...stylex.props(styles.keyGroup, loop.run, styles.loop, styles.shiftKeys)}>
            <Key xstyle={[loop.run, styles.loop, styles.pressFirst]}>{tile.key}</Key>
            <Key xstyle={[loop.run, styles.loop, styles.pressSecond]}>{tile.key}</Key>
          </div>
          <div {...stylex.props(styles.keyGroup, styles.summonGroup, loop.run, styles.loop, styles.summonKeys)}>
            <Key xstyle={[loop.run, styles.loop, styles.pressOption]}>{tile.summonKeys[0]}</Key>
            <Key xstyle={[loop.run, styles.loop, styles.pressN]}>{tile.summonKeys[1]}</Key>
          </div>
        </div>
      </div>
      <MiniPanel xstyle={[styles.panel, loop.run, styles.loop, styles.panelShown]}>
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
    animationDuration: '10040ms',
  },
  stack: {
    position: 'absolute',
    top: { default: 22, [media.wide]: 24 },
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
    marginTop: { default: 10, [media.wide]: 11 },
  },
  keyGroup: {
    display: 'flex',
    gap: 6,
  },
  summonGroup: {
    position: 'absolute',
    top: 0,
    left: 0,
    opacity: 0,
  },
  shiftKeys: {
    animationName: { default: null, [media.motion]: shiftKeysShown },
  },
  summonKeys: {
    animationName: { default: null, [media.motion]: summonKeysShown },
  },
  pressFirst: {
    animationName: { default: null, [media.motion]: pressFirst },
  },
  pressSecond: {
    animationName: { default: null, [media.motion]: pressSecond },
  },
  pressOption: {
    animationName: { default: null, [media.motion]: pressOption },
  },
  pressN: {
    animationName: { default: null, [media.motion]: pressN },
  },
  panel: {
    top: { default: 22, [media.wide]: 24 },
    left: { default: 182, [media.wide]: 316 },
    width: 160,
    height: { default: 287, [media.wide]: 272 },
  },
  panelShown: {
    animationName: { default: null, [media.motion]: panelShown },
  },
  chip: {
    top: { default: 321, [media.wide]: 236 },
    left: { default: 42, [media.wide]: 176 },
    opacity: 0,
  },
  chipIn: {
    animationName: { default: null, [media.motion]: savedChip },
  },
})
