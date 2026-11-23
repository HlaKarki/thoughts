import * as stylex from '@stylexjs/stylex'
import type { ReactNode } from 'react'
import { Photo } from './Photo'
import { color, font, leading, media, radius, size } from '@/styles/tokens.stylex'

type Props = {
  readonly photo: string
  readonly compactWhenNarrow?: boolean
  readonly children: ReactNode
}

export function MiniPage({ photo, compactWhenNarrow = false, children }: Props) {
  return (
    <div {...stylex.props(styles.page, compactWhenNarrow && styles.pageCompact)}>
      <span {...stylex.props(styles.eyebrow)} />
      <span {...stylex.props(styles.spacer, styles.titleSpacer)}>
        <span {...stylex.props(styles.title, compactWhenNarrow && styles.titleCompact)} />
      </span>
      <span {...stylex.props(styles.spacer, styles.photoSpacer)}>
        <Photo src={photo} xstyle={[styles.photo, compactWhenNarrow && styles.photoCompact]} />
      </span>
      <div {...stylex.props(styles.lines)}>
        <span {...stylex.props(styles.headingRow)}>
          <span {...stylex.props(styles.heading)} />
        </span>
        {children}
      </div>
    </div>
  )
}

export function MiniLine({ width }: { readonly width: number }) {
  return (
    <span {...stylex.props(styles.lineRow)}>
      <span {...stylex.props(styles.line, styles.width(width))} />
    </span>
  )
}

type SelectionProps = {
  readonly text: string
  readonly highlightXstyle?: stylex.StyleXStyles
}

export function MiniSelection({ text, highlightXstyle }: SelectionProps) {
  return (
    <span {...stylex.props(styles.lineRow)}>
      <span {...stylex.props(styles.selection)}>
        <span {...stylex.props(styles.highlight, highlightXstyle)} />
        <span {...stylex.props(styles.selectionText)}>{text}</span>
      </span>
    </span>
  )
}

const styles = stylex.create({
  page: {
    display: 'flex',
    flexDirection: 'column',
    paddingBlock: 14,
    paddingInline: 16,
  },
  pageCompact: {
    paddingInline: { default: 12, [media.wide]: 16 },
  },
  eyebrow: {
    flexShrink: 0,
    width: 36,
    height: 4,
    borderRadius: radius.r2,
    backgroundColor: color.bar,
  },
  spacer: {
    display: 'flex',
    flexShrink: 0,
  },
  titleSpacer: {
    paddingTop: 9,
  },
  photoSpacer: {
    paddingTop: 12,
  },
  title: {
    width: 148,
    height: 8,
    borderRadius: radius.r4,
    backgroundColor: color.barStrong,
  },
  titleCompact: {
    width: { default: 100, [media.wide]: 148 },
  },
  photo: {
    width: 232,
    height: 56,
    borderRadius: radius.r6,
    backgroundSize: '232px 154.7px',
    backgroundPosition: '0 -62px',
  },
  photoCompact: {
    width: { default: 132, [media.wide]: 232 },
    backgroundSize: { default: '132px 88px', [media.wide]: '232px 154.7px' },
    backgroundPosition: { default: '0 -24px', [media.wide]: '0 -62px' },
  },
  lines: {
    display: 'flex',
    flexDirection: 'column',
    flexShrink: 0,
    paddingTop: 12,
  },
  headingRow: {
    display: 'flex',
    alignItems: 'center',
    flexShrink: 0,
    height: 14,
  },
  heading: {
    width: 64,
    height: 6,
    borderRadius: radius.r3,
    backgroundColor: color.barHeading,
  },
  lineRow: {
    display: 'flex',
    alignItems: 'center',
    flexShrink: 0,
    height: 16,
  },
  line: {
    height: 5,
    borderRadius: radius.r3,
    backgroundColor: color.barLine,
  },
  width: (width: number) => ({
    width,
  }),
  selection: {
    position: 'relative',
    display: 'flex',
  },
  highlight: {
    position: 'absolute',
    inset: 0,
    backgroundColor: color.selection,
  },
  selectionText: {
    position: 'relative',
    color: color.selectionTextMini,
    fontFamily: font.text,
    fontSize: size.s11,
    lineHeight: leading.l16,
    whiteSpace: 'pre',
  },
})
