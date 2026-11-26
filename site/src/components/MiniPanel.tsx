import * as stylex from '@stylexjs/stylex'
import type { ReactNode } from 'react'
import { GlassPanel } from './GlassPanel'
import { MoreDots, Search } from './Icons'
import { Photo } from './Photo'
import { color, font, leading, radius, size } from '@/styles/tokens.stylex'

type PanelProps = {
  readonly search?: ReactNode
  readonly children: ReactNode
  readonly xstyle?: stylex.StyleXStyles
  readonly listXstyle?: stylex.StyleXStyles
  readonly composerCaretXstyle?: stylex.StyleXStyles
}

export function MiniPanel({ search, children, xstyle, listXstyle, composerCaretXstyle }: PanelProps) {
  return (
    <GlassPanel scale="mini" xstyle={[styles.panel, xstyle]}>
      <div {...stylex.props(styles.header)}>
        <div {...stylex.props(styles.field)}>
          <Search size={9} strokeWidth={2} xstyle={styles.fieldIcon} />
          {search ?? <MiniSearchPlaceholder />}
        </div>
        <span {...stylex.props(styles.menu)}>
          <MoreDots width={11} height={3} r={1.8} xstyle={styles.fieldIcon} />
        </span>
      </div>
      <ul {...stylex.props(styles.list, listXstyle)}>{children}</ul>
      <div {...stylex.props(styles.composer)}>
        <div {...stylex.props(styles.composerField)}>
          <span {...stylex.props(styles.caret, composerCaretXstyle)} />
          <span {...stylex.props(styles.bar, styles.fieldBar, styles.composerBar)} />
        </div>
      </div>
    </GlassPanel>
  )
}

export function MiniSearchPlaceholder({ xstyle }: { readonly xstyle?: stylex.StyleXStyles }) {
  return <span {...stylex.props(styles.bar, styles.fieldBar, styles.searchBar, xstyle)} />
}

type RowProps = {
  readonly time: ReactNode
  readonly children: ReactNode
  readonly element?: 'li' | 'div'
  readonly xstyle?: stylex.StyleXStyles
}

export function MiniRow({ time, children, element: Element = 'li', xstyle }: RowProps) {
  return (
    <Element {...stylex.props(styles.row, xstyle)}>
      <div {...stylex.props(styles.content)}>{children}</div>
      <span {...stylex.props(styles.time)}>{time}</span>
    </Element>
  )
}

export function MiniThumbnail({ src }: { readonly src: string }) {
  return <Photo src={src} xstyle={styles.thumbnail} />
}

type BarsProps = {
  readonly widths: ReadonlyArray<number>
  readonly dim?: boolean
  readonly element?: 'li' | 'div'
  readonly xstyle?: stylex.StyleXStyles
  readonly children?: ReactNode
}

export function MiniBarsRow({ widths, dim = false, element, xstyle, children }: BarsProps) {
  return (
    <MiniRow element={element} xstyle={xstyle} time={<span {...stylex.props(styles.bar, styles.timeBar)} />}>
      <span {...stylex.props(styles.bars)}>
        {widths.map((width, index) => (
          <span key={index} {...stylex.props(styles.bar, styles.lineBar, dim && styles.dimBar, styles.width(width))} />
        ))}
      </span>
      {children}
    </MiniRow>
  )
}

export function MiniSourceBar({ width }: { readonly width: number }) {
  return <span {...stylex.props(styles.bar, styles.sourceBar, styles.width(width))} />
}

const styles = stylex.create({
  panel: {
    position: 'absolute',
  },
  header: {
    display: 'flex',
    alignItems: 'center',
    flexShrink: 0,
    gap: 4,
    paddingTop: 8,
    paddingRight: 6,
    paddingBottom: 6,
    paddingLeft: 8,
  },
  field: {
    display: 'flex',
    alignItems: 'center',
    flexGrow: 1,
    gap: 5,
    height: 22,
    paddingLeft: 8,
    borderRadius: radius.r11,
    backgroundColor: color.field,
  },
  fieldIcon: {
    color: color.fieldIcon,
  },
  menu: {
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'center',
    flexShrink: 0,
    width: 22,
    height: 22,
  },
  list: {
    display: 'flex',
    flexDirection: 'column',
    justifyContent: 'end',
    flexGrow: 1,
    flexBasis: 0,
    minHeight: 0,
    gap: 2,
    overflow: 'clip',
    paddingTop: 4,
    paddingInline: 6,
    paddingBottom: 6,
  },
  composer: {
    display: 'flex',
    flexDirection: 'column',
    flexShrink: 0,
    padding: 8,
  },
  composerField: {
    display: 'flex',
    alignItems: 'center',
    flexShrink: 0,
    gap: 3,
    height: 24,
    paddingLeft: 9,
    borderRadius: radius.r12,
    borderWidth: 1,
    borderStyle: 'solid',
    borderColor: color.composerBorder,
    backgroundColor: color.composer,
  },
  caret: {
    flexShrink: 0,
    width: 1,
    height: 10,
    backgroundColor: color.caret,
  },
  row: {
    display: 'flex',
    alignItems: 'start',
    flexShrink: 0,
    gap: 6,
    paddingBlock: 6,
    paddingInline: 5,
    borderRadius: radius.r6,
    fontFamily: font.text,
    fontSize: size.s11,
    lineHeight: leading.l15,
  },
  content: {
    display: 'flex',
    flexDirection: 'column',
    flexGrow: 1,
    flexBasis: 0,
    minWidth: 0,
    color: color.rowText,
  },
  time: {
    display: 'flex',
    justifyContent: 'end',
    flexShrink: 0,
    width: 30,
    color: color.rowTime,
    textAlign: 'right',
    whiteSpace: 'pre',
  },
  thumbnail: {
    width: 58,
    height: 46,
    borderRadius: radius.r5,
    borderWidth: 1,
    borderStyle: 'solid',
    borderColor: color.thumbBorder,
    backgroundOrigin: 'border-box',
    backgroundSize: '73px 80.3px',
    backgroundPosition: '-5.3px -22.6px',
  },
  bars: {
    display: 'flex',
    flexDirection: 'column',
    gap: 5,
  },
  bar: {
    display: 'block',
    flexShrink: 0,
  },
  lineBar: {
    height: 5,
    borderRadius: radius.r3,
    backgroundColor: color.bar,
  },
  dimBar: {
    backgroundColor: color.barDim,
  },
  timeBar: {
    width: 14,
    height: 4,
    borderRadius: radius.r2,
    backgroundColor: color.barTime,
  },
  sourceBar: {
    height: 4,
    marginTop: 5,
    borderRadius: radius.r2,
    backgroundColor: color.barTime,
  },
  fieldBar: {
    height: 4,
    borderRadius: radius.r2,
    backgroundColor: color.barField,
  },
  searchBar: {
    width: 44,
  },
  composerBar: {
    width: 40,
  },
  width: (width: number) => ({
    width,
  }),
})
