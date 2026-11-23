import * as stylex from '@stylexjs/stylex'
import { SavedChip } from '@/components/Chip'
import { MiniBarsRow, MiniPanel, MiniRow } from '@/components/MiniPanel'
import { MiniLine, MiniPage, MiniSelection } from '@/components/MiniPage'
import { MiniWindow } from '@/components/MiniWindow'
import { features } from '@/content/features'
import { site } from '@/content/site'
import { wrapWords } from '@/lib/wrapWords'
import { layout } from '@/styles/layout'
import { loop } from '@/styles/loop'
import { sequenceStyles } from '@/styles/sequence'
import { reveal } from '@/styles/sequence.stylex'
import { color, font, leading, media, radius, size } from '@/styles/tokens.stylex'
import { Tile } from './Tile'

const tile = features.selection.tile

const sweep = stylex.keyframes({
  '0%': { opacity: 1, clipPath: reveal.clipShown },
  '4%': { opacity: 0, clipPath: reveal.clipShown },
  '4.01%, 5%': { opacity: 1, clipPath: reveal.clipHidden },
  '15%, 100%': { opacity: 1, clipPath: reveal.clipShown },
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

const wideColumns = 33
const narrowColumns = 22

function Selection({ columns }: { readonly columns: number }) {
  const lines = wrapWords(tile.row, columns)
  return lines.map((line, index) => (
    <MiniSelection
      key={index}
      text={line}
      highlightXstyle={[loop.long, styles.sweeping, sequenceStyles.at(index, lines.length)]}
    />
  ))
}

export function SelectionTile() {
  return (
    <Tile label={tile.label}>
      <MiniWindow address xstyle={styles.window} addressXstyle={styles.address}>
        <MiniPage photo={site.photos.bread} compactWhenNarrow>
          <span {...stylex.props(layout.wideFlex, styles.lines)}>
            <MiniLine width={212} />
            <Selection columns={wideColumns} />
            <MiniLine width={150} />
          </span>
          <span {...stylex.props(layout.narrowFlex, styles.lines)}>
            <MiniLine width={120} />
            <Selection columns={narrowColumns} />
            <MiniLine width={96} />
          </span>
        </MiniPage>
      </MiniWindow>
      <div {...stylex.props(styles.keys)}>
        <kbd {...stylex.props(styles.key, loop.long, styles.pressFirst)}>{tile.key}</kbd>
        <kbd {...stylex.props(styles.key, loop.long, styles.pressSecond)}>{tile.key}</kbd>
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
  window: {
    top: { default: 65, [media.wide]: 24 },
    left: { default: 16, [media.wide]: 24 },
    width: { default: 158, [media.wide]: 264 },
  },
  address: {
    left: { default: 48, [media.wide]: 84 },
  },
  lines: {
    flexDirection: 'column',
  },
  sweeping: {
    animationName: { default: null, [media.motion]: sweep },
  },
  keys: {
    position: 'absolute',
    top: { default: 307, [media.wide]: 268 },
    left: { default: 16, [media.wide]: 24 },
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
