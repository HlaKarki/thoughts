import * as stylex from '@stylexjs/stylex'
import { SavedChip } from '@/components/Chip'
import { MiniBarsRow, MiniPanel, MiniRow } from '@/components/MiniPanel'
import { MiniLine, MiniPage, MiniSelection } from '@/components/MiniPage'
import { MiniWindow } from '@/components/MiniWindow'
import { features } from '@/content/features'
import { site } from '@/content/site'
import { layout } from '@/styles/layout'
import { loop } from '@/styles/loop'
import { color, font, leading, media, radius, size } from '@/styles/tokens.stylex'
import { Tile } from './Tile'

const tile = features.selection.tile

const sweep = stylex.keyframes({
  '0%': { opacity: 1, backgroundSize: '100% 100%' },
  '4%': { opacity: 0, backgroundSize: '100% 100%' },
  '4.01%, 5%': { opacity: 1, backgroundSize: '0% 100%' },
  '15%, 100%': { opacity: 1, backgroundSize: '100% 100%' },
})

const pressFirst = stylex.keyframes({
  '0%, 19.99%, 22.01%, 100%': { borderColor: color.keyBorder, translate: '0 0' },
  '20%, 22%': { borderColor: color.accent, translate: '0 1px' },
})

const pressSecond = stylex.keyframes({
  '0%, 23.99%, 26.01%, 100%': { borderColor: color.keyBorder, translate: '0 0' },
  '24%, 26%': { borderColor: color.accent, translate: '0 1px' },
})

const savedChip = stylex.keyframes({
  '0%, 26%': { opacity: 0, translate: '24px 0' },
  '29%, 44%': { opacity: 1, translate: '0 0' },
  '46%, 100%': { opacity: 0, translate: '0 0' },
})

const panelIn = stylex.keyframes({
  '0%': { opacity: 1, translate: '0 0' },
  '4%': { opacity: 0, translate: '0 0' },
  '4.01%, 50%': { opacity: 1, translate: 'calc(100% + 24px) 0' },
  '53%, 100%': { opacity: 1, translate: '0 0' },
})

function Selection() {
  return (
    <MiniSelection
      text={tile.row}
      xstyle={styles.measure}
      linesXstyle={styles.roomForLines}
      highlightXstyle={[loop.long, styles.sweeping]}
    />
  )
}

export function SelectionTile() {
  return (
    <Tile label={tile.label}>
      <div {...stylex.props(styles.stack)}>
        <MiniWindow address xstyle={styles.window} addressXstyle={styles.address}>
          <MiniPage photo={site.photos.bread} compactWhenNarrow>
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
          <kbd {...stylex.props(styles.key, loop.long, styles.pressFirst)}>{tile.key}</kbd>
          <kbd {...stylex.props(styles.key, loop.long, styles.pressSecond)}>{tile.key}</kbd>
        </div>
      </div>
      <MiniPanel xstyle={[styles.panel, loop.long, styles.panelIn]}>
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
      <SavedChip label={tile.saved} xstyle={[styles.chip, loop.long, styles.chipIn]} />
    </Tile>
  )
}

const styles = stylex.create({
  stack: {
    position: 'absolute',
    top: { default: 65, [media.wide]: 24 },
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
    maxWidth: { default: 120, [media.wide]: 200 },
  },
  roomForLines: {
    WebkitLineClamp: { default: 3, [media.wide]: 2 },
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
  panelIn: {
    animationName: { default: null, [media.motion]: panelIn },
  },
  chip: {
    top: { default: 344, [media.wide]: 256 },
    left: { default: 178, [media.wide]: 312 },
    opacity: 0,
  },
  chipIn: {
    animationName: { default: null, [media.motion]: savedChip },
    animationTimingFunction: 'ease-out',
  },
})
