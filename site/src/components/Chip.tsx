import * as stylex from '@stylexjs/stylex'
import type { ReactNode } from 'react'
import { Keycap } from './Keycap'
import { Photo } from './Photo'
import { Tick } from './Icons'
import { color, font, leading, radius, size } from '@/styles/tokens.stylex'

type ChipProps = {
  readonly children: ReactNode
  readonly xstyle?: stylex.StyleXStyles
}

function Chip({ children, xstyle }: ChipProps) {
  return <div {...stylex.props(styles.chip, xstyle)}>{children}</div>
}

type SavedProps = {
  readonly label: string
  readonly xstyle?: stylex.StyleXStyles
}

export function SavedChip({ label, xstyle }: SavedProps) {
  return (
    <Chip xstyle={[styles.saved, xstyle]}>
      <span {...stylex.props(styles.savedSlot)}>
        <Tick xstyle={styles.tick} />
      </span>
      <span {...stylex.props(styles.title)}>{label}</span>
    </Chip>
  )
}

type OfferProps = {
  readonly title: string
  readonly subtitle: string
  readonly keys: string
  readonly image: string
  readonly xstyle?: stylex.StyleXStyles
}

export function OfferChip({ title, subtitle, keys, image, xstyle }: OfferProps) {
  return (
    <Chip xstyle={[styles.offer, xstyle]}>
      <Photo src={image} xstyle={styles.offerSlot} />
      <span {...stylex.props(styles.offerText)}>
        <span {...stylex.props(styles.title)}>{title}</span>
        <span {...stylex.props(styles.subtitle)}>{subtitle}</span>
      </span>
      <Keycap variant="offer">{keys}</Keycap>
    </Chip>
  )
}

const styles = stylex.create({
  chip: {
    position: 'absolute',
    display: 'flex',
    alignItems: 'center',
    gap: 8,
    paddingLeft: 7,
    borderRadius: radius.r10,
    borderWidth: 1,
    borderStyle: 'solid',
    borderColor: color.chipBorder,
    backgroundColor: color.chip,
    boxShadow: color.chipShadow,
    fontFamily: font.text,
  },
  saved: {
    width: 164,
    height: 40,
    paddingRight: 10,
  },
  savedSlot: {
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'center',
    flexShrink: 0,
    width: 26,
    height: 26,
    borderRadius: radius.r5,
    backgroundColor: color.chipSlot,
  },
  tick: {
    color: color.success,
  },
  offer: {
    width: 196,
    height: 44,
    paddingRight: 9,
  },
  offerSlot: {
    width: 30,
    height: 30,
    borderRadius: radius.r6,
    backgroundSize: '53.8px 59.2px',
    backgroundPosition: '-10.3px -18.7px',
  },
  offerText: {
    display: 'flex',
    flexDirection: 'column',
    flexGrow: 1,
    flexBasis: 0,
    minWidth: 0,
  },
  title: {
    color: color.chipTitle,
    fontSize: size.s12,
    fontWeight: 600,
    lineHeight: leading.l16,
    whiteSpace: 'pre',
  },
  subtitle: {
    color: color.chipSubtitle,
    fontSize: size.s11,
    lineHeight: leading.l14,
    whiteSpace: 'pre',
  },
})
