import * as stylex from '@stylexjs/stylex'
import { OfferChip } from '@/components/Chip'
import { Collapse } from '@/components/Collapse'
import { MiniBarsRow, MiniPanel, MiniRow, MiniThumbnail } from '@/components/MiniPanel'
import { MiniWindow } from '@/components/MiniWindow'
import { Photo } from '@/components/Photo'
import { features } from '@/content/features'
import { layout } from '@/styles/layout'
import { loop } from '@/styles/loop'
import { color, media } from '@/styles/tokens.stylex'
import { Tile } from './Tile'

const tile = features.screenshot.tile

const capture = stylex.keyframes({
  '0%, 10%': { opacity: 0, clipPath: 'inset(0 100% 100% 0)' },
  '10.01%': { opacity: 1, clipPath: 'inset(0 100% 100% 0)' },
  '18%, 20.99%': { opacity: 1, clipPath: 'inset(0 0 0 0)' },
  '21%, 100%': { opacity: 0, clipPath: 'inset(0 0 0 0)' },
})

const flash = stylex.keyframes({
  '0%, 19%': { opacity: 0 },
  '20%': { opacity: 0.6 },
  '21%, 100%': { opacity: 0 },
})

const offer = stylex.keyframes({
  '0%, 24%': { opacity: 0, translate: '24px 0', scale: 1 },
  '26%, 44.99%': { opacity: 1, translate: '0 0', scale: 1 },
  '45%, 46.87%': { opacity: 1, translate: '0 0', scale: 0.97 },
  '46.88%, 48%': { opacity: 1, translate: '0 0', scale: 1 },
  '50%, 100%': { opacity: 0, translate: '0 0', scale: 1 },
})

const grow = stylex.keyframes({
  '0%': { gridTemplateRows: '1fr', opacity: 1 },
  '4%': { gridTemplateRows: '1fr', opacity: 0 },
  '4.01%, 48%': { gridTemplateRows: '0fr', opacity: 0 },
  '50%, 100%': { gridTemplateRows: '1fr', opacity: 1 },
})

export function ScreenshotTile() {
  return (
    <Tile label={tile.label}>
      <MiniWindow title={tile.windowTitle} strongTitle xstyle={styles.window} titleXstyle={styles.title}>
        <Photo src={tile.photo} xstyle={styles.photo}>
          <span {...stylex.props(styles.flash, loop.long, styles.flashing)} />
        </Photo>
      </MiniWindow>
      <MiniPanel xstyle={styles.panel}>
        <MiniBarsRow widths={[96, 60]} xstyle={layout.narrowFlex} />
        <MiniBarsRow widths={[88]} xstyle={layout.narrowFlex} />
        <MiniBarsRow widths={[70]} dim xstyle={layout.narrowFlex} />
        <MiniBarsRow widths={[96, 60]} />
        <MiniBarsRow widths={[70]} dim />
        <MiniBarsRow widths={[88]} />
        <MiniBarsRow widths={[100, 44]} />
        <MiniBarsRow widths={[76]} />
        <Collapse element="li" xstyle={[loop.long, styles.grow]}>
          <MiniRow element="div" time={tile.time}>
            <MiniThumbnail src={tile.photo} />
          </MiniRow>
        </Collapse>
      </MiniPanel>
      <span {...stylex.props(styles.region, loop.long, styles.capturing)} />
      <OfferChip
        title={tile.offerTitle}
        message={tile.offerMessage}
        keys={tile.offerKeys}
        image={tile.photo}
        xstyle={[styles.offer, loop.long, styles.offering]}
      />
    </Tile>
  )
}

const styles = stylex.create({
  window: {
    top: { default: 62, [media.wide]: 24 },
    left: { default: 16, [media.wide]: 24 },
    width: { default: 158, [media.wide]: 264 },
    height: { default: 260, [media.wide]: 272 },
  },
  title: {
    left: { default: 44, [media.wide]: 0 },
    width: { default: 108, [media.wide]: '100%' },
  },
  photo: {
    flexGrow: 1,
    flexBasis: 0,
    backgroundColor: color.windowBg,
    backgroundSize: { default: '222.7px 244.8px', [media.wide]: '262px 288px' },
    backgroundPosition: { default: '-29px -6px', [media.wide]: '0 -40px' },
  },
  flash: {
    position: 'absolute',
    inset: 0,
    backgroundColor: color.flash,
    opacity: 0,
  },
  flashing: {
    animationName: { default: null, [media.motion]: flash },
  },
  panel: {
    top: { default: 16, [media.wide]: 24 },
    left: { default: 182, [media.wide]: 316 },
    width: 160,
    height: { default: 368, [media.wide]: 272 },
  },
  grow: {
    animationName: { default: null, [media.motion]: grow },
  },
  region: {
    position: 'absolute',
    top: { default: 118, [media.wide]: 90 },
    left: { default: 24, [media.wide]: 44 },
    width: { default: 140, [media.wide]: 208 },
    height: { default: 150, [media.wide]: 166 },
    borderWidth: 1,
    borderStyle: 'dashed',
    borderColor: color.captureBorder,
    backgroundColor: color.capture,
    opacity: 0,
  },
  capturing: {
    animationName: { default: null, [media.motion]: capture },
  },
  offer: {
    top: { default: 324, [media.wide]: 236 },
    left: { default: 42, [media.wide]: 176 },
    opacity: 0,
  },
  offering: {
    animationName: { default: null, [media.motion]: offer },
  },
})
