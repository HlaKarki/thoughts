import * as stylex from '@stylexjs/stylex'
import { AppIcon } from '@/components/AppIcon'
import { Grain } from '@/components/Grain'
import { hero } from '@/content/hero'
import { color, media, radius, scene, space, width } from '@/styles/tokens.stylex'
import { BrowserWindow } from './hero/BrowserWindow'
import { HeroPanel } from './hero/HeroPanel'
import { MenuBar } from './hero/MenuBar'

const cropHeight = { default: 1000, [media.wide]: 800 }

const settle = stylex.keyframes({
  from: { scale: 0.96, borderRadius: '8px' },
})

export function Hero() {
  return (
    <section {...stylex.props(styles.hero)}>
      <div role="img" aria-label={hero.label} {...stylex.props(styles.crop)}>
        <div aria-hidden {...stylex.props(styles.scene)}>
          <Grain />
          <MenuBar />
          <BrowserWindow />
          <HeroPanel />
        </div>
      </div>
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
    paddingTop: { default: 48, [media.wide]: 64 },
    paddingBottom: { default: 96, [media.wide]: 64 },
  },
  crop: {
    position: 'relative',
    width: { default: '100%', [media.wide]: `min(${width.scene}, 100% - 2 * ${space.gutter})` },
    height: cropHeight,
    overflow: 'clip',
    borderRadius: { default: 0, [media.wide]: radius.r16 },
    animationName: {
      default: null,
      [media.wide]: {
        default: null,
        [media.motion]: {
          default: null,
          [media.scrollTimeline]: settle,
        },
      },
    },
    animationTimingFunction: 'linear',
    animationFillMode: 'both',
    animationTimeline: 'view()',
    animationRange: 'entry 0% entry 100%',
  },
  scene: {
    position: 'absolute',
    top: 0,
    right: { default: -1, [media.wide]: 0 },
    width: width.scene,
    height: '100%',
    overflow: 'clip',
    backgroundImage: scene.wallpaper,
  },
  icon: {
    position: 'absolute',
    left: '50%',
    top: cropHeight,
    width: { default: 96, [media.wide]: 128 },
    height: { default: 96, [media.wide]: 128 },
    translate: '-50% 0',
    filter: {
      default: `drop-shadow(${color.iconShadow} 0 6px 18px)`,
      [media.wide]: `drop-shadow(${color.iconShadow} 0 8px 24px)`,
    },
  },
})
