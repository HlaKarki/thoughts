import * as stylex from '@stylexjs/stylex'
import type { ReactNode } from 'react'
import { color, font, leading, radius, size } from '@/styles/tokens.stylex'

type Props = {
  readonly title?: string
  readonly strongTitle?: boolean
  readonly address?: boolean
  readonly children: ReactNode
  readonly xstyle?: stylex.StyleXStyles
  readonly titleXstyle?: stylex.StyleXStyles
  readonly addressXstyle?: stylex.StyleXStyles
}

export function MiniWindow({
  title,
  strongTitle = false,
  address = false,
  children,
  xstyle,
  titleXstyle,
  addressXstyle,
}: Props) {
  return (
    <div {...stylex.props(styles.window, xstyle)}>
      <div {...stylex.props(styles.titleBar)}>
        <span {...stylex.props(styles.light, styles.red)} />
        <span {...stylex.props(styles.light, styles.yellow)} />
        <span {...stylex.props(styles.light, styles.green)} />
        {address ? (
          <span {...stylex.props(styles.address, addressXstyle)}>
            <span {...stylex.props(styles.addressBar)} />
          </span>
        ) : null}
        {title ? (
          <span {...stylex.props(styles.title, strongTitle && styles.titleStrong, titleXstyle)}>{title}</span>
        ) : null}
      </div>
      {children}
    </div>
  )
}

const styles = stylex.create({
  window: {
    position: 'absolute',
    display: 'flex',
    flexDirection: 'column',
    overflow: 'clip',
    borderRadius: radius.r10,
    borderWidth: 1,
    borderStyle: 'solid',
    borderColor: color.windowBorder,
    backgroundColor: color.windowBg,
    boxShadow: color.windowShadowMini,
  },
  titleBar: {
    position: 'relative',
    display: 'flex',
    alignItems: 'center',
    flexShrink: 0,
    gap: 5,
    height: 24,
    paddingLeft: 10,
    backgroundColor: color.toolbar,
    borderBottomWidth: 1,
    borderBottomStyle: 'solid',
    borderBottomColor: color.titleBarBorder,
  },
  light: {
    flexShrink: 0,
    width: 7,
    height: 7,
    borderRadius: radius.r4,
  },
  red: { backgroundColor: color.trafficRed },
  yellow: { backgroundColor: color.trafficYellow },
  green: { backgroundColor: color.trafficGreen },
  address: {
    position: 'absolute',
    top: 5,
    left: 84,
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'center',
    width: 96,
    height: 14,
    borderRadius: radius.r7,
    backgroundColor: color.addressMini,
  },
  addressBar: {
    width: 40,
    height: 4,
    borderRadius: radius.r2,
    backgroundColor: color.bar,
  },
  title: {
    position: 'absolute',
    top: 4,
    left: 0,
    right: 0,
    color: color.titleText,
    fontFamily: font.text,
    fontSize: size.s11,
    fontWeight: 600,
    lineHeight: leading.l16,
    textAlign: 'center',
    whiteSpace: 'pre',
    overflow: 'clip',
    textOverflow: 'ellipsis',
  },
  titleStrong: {
    color: color.titleTextStrong,
  },
})
