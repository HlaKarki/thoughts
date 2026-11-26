import * as stylex from '@stylexjs/stylex'
import { useEffect, useState } from 'react'
import { color, font, leading, radius, size } from '@/styles/tokens.stylex'

type Props = {
  readonly command: string
  readonly xstyle?: stylex.StyleXStyles
}

const copiedFor = 2000

export function CopyCommand({ command, xstyle }: Props) {
  const [copied, setCopied] = useState(false)

  useEffect(() => {
    if (!copied) return
    const timer = setTimeout(() => setCopied(false), copiedFor)
    return () => clearTimeout(timer)
  }, [copied])

  async function copy() {
    try {
      await navigator.clipboard.writeText(command)
      setCopied(true)
    } catch {
      setCopied(false)
    }
  }

  return (
    <div {...stylex.props(styles.field, xstyle)}>
      <code {...stylex.props(styles.command)}>{command}</code>
      <button type="button" onClick={copy} {...stylex.props(styles.copy)}>
        <span aria-live="polite">{copied ? 'Copied' : 'Copy'}</span>
      </button>
    </div>
  )
}

const styles = stylex.create({
  field: {
    display: 'flex',
    alignItems: 'center',
    gap: 8,
    minWidth: 0,
    height: 44,
    paddingInlineStart: 18,
    paddingInlineEnd: 6,
    borderRadius: radius.r22,
    borderWidth: 1,
    borderStyle: 'solid',
    borderColor: color.hairline,
    backgroundColor: color.card,
  },
  command: {
    flexGrow: 1,
    minWidth: 0,
    overflow: 'hidden',
    color: color.textCode,
    fontFamily: font.mono,
    fontSize: size.s13,
    lineHeight: leading.l20,
    whiteSpace: 'nowrap',
    textOverflow: 'ellipsis',
    userSelect: 'all',
  },
  copy: {
    flexShrink: 0,
    minWidth: 64,
    height: 32,
    paddingInline: 12,
    borderRadius: radius.r16,
    borderWidth: 0,
    backgroundColor: {
      default: 'transparent',
      ':hover': color.hairline,
    },
    color: color.textMuted,
    fontFamily: font.text,
    fontSize: size.s13,
    fontWeight: 500,
    lineHeight: leading.l16,
    cursor: 'pointer',
    outlineOffset: 2,
    transitionProperty: 'background-color',
    transitionDuration: '150ms',
  },
})
