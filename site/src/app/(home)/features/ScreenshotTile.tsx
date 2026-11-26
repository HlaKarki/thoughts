import * as stylex from '@stylexjs/stylex'
import { OfferChip } from '@/components/Chip'
import { Collapse } from '@/components/Collapse'
import { MiniBarsRow, MiniPanel, MiniRow, MiniThumbnail } from '@/components/MiniPanel'
import { MiniWindow } from '@/components/MiniWindow'
import { Photo } from '@/components/Photo'
import { features } from '@/content/features'
import { layout } from '@/styles/layout'
import { loop } from '@/styles/loop'
import { color, media, motion } from '@/styles/tokens.stylex'
import { Tile } from './Tile'

const tile = features.screenshot.tile

const capture = stylex.keyframes({
  '0%, 10.582%': { opacity: 1, clipPath: 'inset(0 100% 100% 0)', animationTimingFunction: motion.easeInOut },
  '21.164%': { opacity: 1, clipPath: 'inset(0 0 0 0)', animationTimingFunction: motion.atOnce },
  '23.81%, 100%': { opacity: 1, clipPath: 'inset(0 100% 100% 0)' },
})

const offer = stylex.keyframes({
  '0%, 27.778%': { opacity: 0, translate: '24px 0', animationTimingFunction: motion.appEaseOut },
  '30.423%, 54.233%': { opacity: 1, translate: '0 0', animationTimingFunction: motion.appEaseOut },
  '56.878%, 100%': { opacity: 0, translate: '24px 0' },
})

const added = stylex.keyframes({
  '0%': { gridTemplateRows: '0fr', opacity: 0, animationTimingFunction: motion.atOnce },
  '56.878%, 93.915%': { gridTemplateRows: '1fr', opacity: 1, animationTimingFunction: motion.atOnce },
  '94.312%, 100%': { gridTemplateRows: '0fr', opacity: 0 },
})

const listReset = stylex.keyframes({
  '0%, 88.624%': { opacity: 1, animationTimingFunction: motion.easeIn },
  '93.915%, 94.709%': { opacity: 0, animationTimingFunction: motion.easeOut },
  '100%': { opacity: 1 },
})

export function ScreenshotTile() {
  const run = [loop.run, styles.loop]
  return (
    <Tile label={tile.label}>
      <MiniWindow title={tile.windowTitle} strongTitle xstyle={styles.window} titleXstyle={styles.title}>
        <Photo src={tile.photo} xstyle={styles.photo} />
      </MiniWindow>
      <MiniPanel xstyle={styles.panel} listXstyle={[run, styles.resetting]}>
        <MiniBarsRow widths={[96, 60]} xstyle={layout.narrowFlex} />
        <MiniBarsRow widths={[88]} xstyle={layout.narrowFlex} />
        <MiniBarsRow widths={[70]} dim xstyle={layout.narrowFlex} />
        <MiniBarsRow widths={[96, 60]} />
        <MiniBarsRow widths={[70]} dim />
        <MiniBarsRow widths={[88]} />
        <MiniBarsRow widths={[100, 44]} />
        <MiniBarsRow widths={[76]} />
        <Collapse element="li" xstyle={[run, styles.adding]}>
          <MiniRow element="div" time={tile.time}>
            <MiniThumbnail src={tile.photo} />
            <span {...stylex.props(styles.note)}>{tile.note}</span>
          </MiniRow>
        </Collapse>
      </MiniPanel>
      <span {...stylex.props(styles.region, run, styles.capturing)} />
      <OfferChip
        title={tile.offerTitle}
        message={tile.offerMessage}
        keys={tile.offerKeys}
        image={tile.photo}
        xstyle={[styles.offer, run, styles.offering]}
      />
    </Tile>
  )
}

const styles = stylex.create({
  loop: {
    animationDuration: '7560ms',
  },
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
  panel: {
    top: { default: 16, [media.wide]: 24 },
    left: { default: 182, [media.wide]: 316 },
    width: 160,
    height: { default: 368, [media.wide]: 272 },
  },
  note: {
    paddingTop: 4,
  },
  adding: {
    animationName: { default: null, [media.motion]: added },
  },
  resetting: {
    animationName: { default: null, [media.motion]: listReset },
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
