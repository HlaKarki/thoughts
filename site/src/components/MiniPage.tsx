import * as stylex from '@stylexjs/stylex'
import type { ReactNode } from 'react'
import { color, font, leading, media, radius, size } from '@/styles/tokens.stylex'

type Props = {
  readonly code?: boolean
  readonly compactWhenNarrow?: boolean
  readonly children: ReactNode
}

export function MiniPage({ code = false, compactWhenNarrow = false, children }: Props) {
  return (
    <div {...stylex.props(styles.page, compactWhenNarrow && styles.pageCompact)}>
      <span {...stylex.props(styles.eyebrow)} />
      <span {...stylex.props(styles.spacer, styles.titleSpacer)}>
        <span {...stylex.props(styles.title, compactWhenNarrow && styles.titleCompact)} />
      </span>
      {code && (
        <span {...stylex.props(styles.spacer, styles.codeSpacer)}>
          <span {...stylex.props(styles.code, compactWhenNarrow && styles.codeCompact)}>
            <span {...stylex.props(styles.codeRow)}>
              <span {...stylex.props(styles.codeBar, styles.codeKeyword)} />
              <span {...stylex.props(styles.codeBar, styles.width(84))} />
            </span>
            <span {...stylex.props(styles.codeRow, styles.codeIndent)}>
              <span {...stylex.props(styles.codeBar, styles.codeLong)} />
            </span>
            <span {...stylex.props(styles.codeRow)}>
              <span {...stylex.props(styles.codeBar, styles.width(12))} />
            </span>
          </span>
        </span>
      )}
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
  readonly xstyle?: stylex.StyleXStyles
  readonly linesXstyle?: stylex.StyleXStyles
  readonly highlightXstyle?: stylex.StyleXStyles
}

export function MiniSelection({ text, xstyle, linesXstyle, highlightXstyle }: SelectionProps) {
  return (
    <span {...stylex.props(styles.selection, xstyle)}>
      <span {...stylex.props(styles.selectionLayer, styles.highlightLayer, linesXstyle)}>
        <span {...stylex.props(styles.highlight, highlightXstyle)}>{text}</span>
      </span>
      <span {...stylex.props(styles.selectionLayer, styles.textLayer, linesXstyle)}>{text}</span>
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
  codeSpacer: {
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
  code: {
    display: 'flex',
    flexDirection: 'column',
    justifyContent: 'center',
    gap: 8,
    width: 232,
    height: 56,
    paddingInline: 12,
    borderRadius: radius.r6,
    backgroundColor: color.barDim,
  },
  codeCompact: {
    gap: { default: 5, [media.wide]: 8 },
    width: { default: 132, [media.wide]: 232 },
    height: { default: 40, [media.wide]: 56 },
    paddingInline: { default: 10, [media.wide]: 12 },
  },
  codeRow: {
    display: 'flex',
    gap: 5,
  },
  codeIndent: {
    paddingLeft: 12,
  },
  codeBar: {
    flexShrink: 1,
    minWidth: 0,
    height: 4,
    borderRadius: radius.r2,
    backgroundColor: color.bar,
  },
  codeKeyword: {
    width: 30,
    flexShrink: 0,
    backgroundColor: color.accent,
    opacity: 0.6,
  },
  codeLong: {
    width: 150,
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
    display: 'block',
    flexShrink: 0,
    fontFamily: font.text,
    fontSize: size.s11,
    lineHeight: leading.l16,
  },
  selectionLayer: {
    display: '-webkit-box',
    WebkitBoxOrient: 'vertical',
    overflow: 'hidden',
  },
  highlightLayer: {
    position: 'absolute',
    inset: 0,
    color: 'transparent',
  },
  highlight: {
    paddingBlock: 1.5,
    backgroundImage: `linear-gradient(${color.selection}, ${color.selection})`,
    backgroundRepeat: 'no-repeat',
    backgroundSize: '100% 100%',
  },
  textLayer: {
    position: 'relative',
    color: color.selectionTextMini,
  },
})
