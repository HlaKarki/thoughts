import * as stylex from '@stylexjs/stylex'
import { AppleLogo, Battery, ControlCenter, Search, ThoughtsCaret, Wifi } from '@/components/Icons'
import { hero } from '@/content/hero'
import { color, font, leading, size } from '@/styles/tokens.stylex'

export function MenuBar() {
  return (
    <div {...stylex.props(styles.bar)}>
      <div {...stylex.props(styles.group, styles.menus)}>
        <AppleLogo />
        <span {...stylex.props(styles.app)}>{hero.menuBar.app}</span>
        {hero.menuBar.menus.map((menu) => (
          <span key={menu}>{menu}</span>
        ))}
      </div>
      <div {...stylex.props(styles.group, styles.status)}>
        <ThoughtsCaret />
        <Battery outline={styles.batteryOutline} />
        <Wifi />
        <Search />
        <ControlCenter />
        <span>{hero.menuBar.clock}</span>
      </div>
    </div>
  )
}

const styles = stylex.create({
  bar: {
    position: 'absolute',
    top: 0,
    left: 0,
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'space-between',
    width: '100%',
    height: 24,
    paddingLeft: 20,
    paddingRight: 16,
    color: color.menuText,
    fontFamily: font.text,
    fontSize: size.s13,
    lineHeight: leading.l16,
    whiteSpace: 'pre',
  },
  group: {
    display: 'flex',
    alignItems: 'center',
  },
  menus: {
    gap: 20,
  },
  status: {
    gap: 16,
  },
  app: {
    fontWeight: 700,
  },
  batteryOutline: {
    color: color.menuBatteryOutline,
  },
})
