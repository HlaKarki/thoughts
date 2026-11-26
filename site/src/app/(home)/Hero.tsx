import * as stylex from '@stylexjs/stylex'
import { useLayoutEffect, useRef, useState, type CSSProperties } from 'react'
import { AppIcon } from '@/components/AppIcon'
import { Grain } from '@/components/Grain'
import { SendToMac } from '@/components/SendToMac'
import { hero } from '@/content/hero'
import { color, font, leading, media, radius, scene, size, space, width } from '@/styles/tokens.stylex'
import { BrowserWindow } from './hero/BrowserWindow'
import { HeroPanel } from './hero/HeroPanel'
import { MenuBar } from './hero/MenuBar'

const cropHeight = { default: 'calc(918px * var(--mini))', [media.wide]: '800px' }
const sceneWidth = 1280
const phoneGuess = 0.27

function useMiniScale() {
  const frame = useRef<HTMLDivElement>(null)
  const [scale, setScale] = useState(phoneGuess)
  useLayoutEffect(() => {
    const node = frame.current
    if (!node) return
    const observer = new ResizeObserver(() => setScale(node.clientWidth / sceneWidth))
    observer.observe(node)
    return () => observer.disconnect()
  }, [])
  return { frame, scale }
}

export function Hero() {
  const { frame, scale } = useMiniScale()
  return (
    <section {...stylex.props(styles.hero)} style={{ '--mini': scale } as CSSProperties}>
      <div ref={frame} role="img" aria-label={hero.label} {...stylex.props(styles.crop)}>
        <div aria-hidden {...stylex.props(styles.scene)}>
          <Grain />
          <MenuBar />
          <BrowserWindow />
          <HeroPanel />
        </div>
      </div>
      <p {...stylex.props(styles.caption)}>{hero.caption}</p>
      <SendToMac xstyle={styles.send} />
      <AppIcon size={128} decorative xstyle={styles.icon} />
    </section>
  )
}

const styles = stylex.create({
  hero: {
    position: 'relative',
    display: 'flex',
    flexDirection: 'column',
    alignItems: 'center',
    gap: { default: 16, [media.wide]: 0 },
    paddingInline: { default: space.gutter, [media.wide]: 0 },
    paddingTop: { default: 40, [media.wide]: 64 },
    paddingBottom: { default: 24, [media.wide]: 64 },
  },
  crop: {
    position: 'relative',
    width: { default: 'calc(100% - 12px)', [media.wide]: `min(${width.scene}, 100% - 2 * ${space.gutter})` },
    height: cropHeight,
    overflow: 'clip',
    borderRadius: { default: radius.r12, [media.wide]: radius.r16 },
    outlineWidth: { default: 6, [media.wide]: 0 },
    outlineStyle: 'solid',
    outlineColor: '#1D1D1F',
    boxShadow: { default: color.windowShadowMini, [media.wide]: 'none' },
    marginTop: { default: 6, [media.wide]: 0 },
  },
  scene: {
    position: 'absolute',
    top: 0,
    left: { default: 0, [media.wide]: 'auto' },
    right: { default: 'auto', [media.wide]: 0 },
    width: width.scene,
    height: { default: 918, [media.wide]: '100%' },
    overflow: 'clip',
    backgroundImage: scene.wallpaper,
    scale: { default: 'var(--mini)', [media.wide]: 'none' },
    transformOrigin: '0 0',
  },
  caption: {
    display: { default: 'block', [media.wide]: 'none' },
    paddingTop: 8,
    color: color.textMuted,
    fontFamily: font.text,
    fontSize: size.s13,
    lineHeight: leading.l18,
    textAlign: 'center',
    textWrap: 'balance',
  },
  send: {
    display: { default: 'flex', [media.pointer]: 'none' },
    width: '100%',
    paddingTop: 16,
  },
  icon: {
    display: { default: 'none', [media.wide]: 'block' },
    position: 'absolute',
    left: '50%',
    top: cropHeight,
    width: 128,
    height: 128,
    translate: '-50% 0',
    filter: `drop-shadow(${color.iconShadow} 0 8px 24px)`,
  },
})
