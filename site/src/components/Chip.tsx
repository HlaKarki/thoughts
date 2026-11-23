import * as stylex from '@stylexjs/stylex'
import type { ReactNode } from 'react'
import { Keycap } from './Keycap'
import { Photo } from './Photo'
import { color, font, leading, radius, size } from '@/styles/tokens.stylex'

type ChipProps = {
  readonly children: ReactNode
  readonly xstyle?: stylex.StyleXStyles
}

function Chip({ children, xstyle }: ChipProps) {
  return <div {...stylex.props(styles.chip, xstyle)}>{children}</div>
}

type SavedProps = {
  readonly title: string
  readonly message: string
  readonly xstyle?: stylex.StyleXStyles
}

export function SavedChip({ title, message, xstyle }: SavedProps) {
  return (
    <Chip xstyle={[styles.wordsOnly, xstyle]}>
      <ChipText title={title} message={message} />
    </Chip>
  )
}

type OfferProps = {
  readonly title: string
  readonly message: string
  readonly keys: string
  readonly image: string
  readonly xstyle?: stylex.StyleXStyles
}

export function OfferChip({ title, message, keys, image, xstyle }: OfferProps) {
  return (
    <Chip xstyle={xstyle}>
      <Photo src={image} xstyle={styles.slot} />
      <ChipText title={title} message={message} />
      <Keycap variant="offer">{keys}</Keycap>
    </Chip>
  )
}

function ChipText({ title, message }: { readonly title: string; readonly message: string }) {
  return (
    <span {...stylex.props(styles.text)}>
      <span {...stylex.props(styles.title)}>{title}</span>
      <span {...stylex.props(styles.message)}>{message}</span>
    </span>
  )
}

const styles = stylex.create({
  chip: {
    position: 'absolute',
    display: 'flex',
    alignItems: 'center',
    gap: 10,
    width: 300,
    height: 60,
    paddingLeft: 10,
    paddingRight: 12,
    borderRadius: radius.r14,
    borderWidth: 1,
    borderStyle: 'solid',
    borderColor: color.chipBorder,
    backgroundColor: color.chip,
    boxShadow: color.chipShadow,
    fontFamily: font.text,
  },
  wordsOnly: {
    paddingLeft: 16,
  },
  slot: {
    flexShrink: 0,
    width: 40,
    height: 40,
    borderRadius: radius.r7,
    backgroundSize: '71.7px 78.9px',
    backgroundPosition: '-13.7px -24.9px',
  },
  text: {
    display: 'flex',
    flexDirection: 'column',
    flexGrow: 1,
    flexBasis: 0,
    minWidth: 0,
  },
  title: {
    color: color.chipTitle,
    fontSize: size.s13,
    fontWeight: 600,
    lineHeight: leading.l18,
    whiteSpace: 'nowrap',
  },
  message: {
    display: '-webkit-box',
    overflow: 'hidden',
    WebkitBoxOrient: 'vertical',
    WebkitLineClamp: 2,
    color: color.chipSubtitle,
    fontSize: size.s12,
    lineHeight: leading.l16,
  },
})
