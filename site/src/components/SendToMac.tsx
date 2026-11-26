import * as stylex from '@stylexjs/stylex'
import { useEffect, useState } from 'react'
import { intro } from '@/content/intro'
import { site } from '@/content/site'
import { color, font, leading, radius, size } from '@/styles/tokens.stylex'

type Props = {
  readonly xstyle?: stylex.StyleXStyles
}

const send = intro.send
const copiedFor = 2000

async function copyLink() {
  if (navigator.clipboard) {
    await navigator.clipboard.writeText(site.url)
    return
  }
  const field = document.createElement('textarea')
  field.value = site.url
  field.setAttribute('readonly', '')
  field.style.position = 'fixed'
  field.style.opacity = '0'
  document.body.append(field)
  field.select()
  const copied = document.execCommand('copy')
  field.remove()
  if (!copied) throw new Error('copy failed')
}

export function SendToMac({ xstyle }: Props) {
  const [copied, setCopied] = useState(false)

  useEffect(() => {
    if (!copied) return
    const timer = setTimeout(() => setCopied(false), copiedFor)
    return () => clearTimeout(timer)
  }, [copied])

  async function share() {
    if (navigator.share) {
      try {
        await navigator.share({ title: site.title, url: site.url })
      } catch {
        return
      }
      return
    }
    try {
      await copyLink()
      setCopied(true)
    } catch {
      setCopied(false)
    }
  }

  return (
    <div {...stylex.props(styles.send, xstyle)}>
      <button type="button" onClick={share} {...stylex.props(styles.button)}>
        <span aria-live="polite">{copied ? send.copied : send.label}</span>
      </button>
      <p {...stylex.props(styles.note)}>{send.note}</p>
    </div>
  )
}

const styles = stylex.create({
  send: {
    display: 'flex',
    flexDirection: 'column',
    alignItems: 'center',
    gap: 10,
  },
  button: {
    width: '100%',
    height: 50,
    borderRadius: radius.r14,
    borderWidth: 0,
    backgroundColor: color.text,
    color: color.pageBg,
    fontFamily: font.text,
    fontSize: size.s17,
    fontWeight: 600,
    cursor: 'pointer',
    outlineOffset: 3,
  },
  note: {
    color: color.textMuted,
    fontFamily: font.text,
    fontSize: size.s13,
    lineHeight: leading.l18,
    textAlign: 'center',
  },
})
