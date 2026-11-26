import * as stylex from '@stylexjs/stylex'
import { AppIcon } from '@/components/AppIcon'
import { header } from '@/content/header'
import { color, font, leading, media, radius, size, space } from '@/styles/tokens.stylex'

export function Header() {
  return (
    <header {...stylex.props(styles.header)}>
      <a href="/" aria-label={header.homeLabel} {...stylex.props(styles.brand)}>
        <AppIcon size={32} decorative xstyle={styles.icon} />
        <span {...stylex.props(styles.name)}>{header.brand}</span>
      </a>
      <nav aria-label={header.navLabel}>
        <a href={header.compact.href} {...stylex.props(styles.compact)}>
          {header.compact.label}
        </a>
        <ul {...stylex.props(styles.nav)}>
          {header.nav.map((link) => (
            <li key={link.href}>
              <a href={link.href} {...stylex.props(styles.link)}>
                {link.label}
              </a>
            </li>
          ))}
        </ul>
      </nav>
    </header>
  )
}

const styles = stylex.create({
  header: {
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'space-between',
    height: { default: 56, [media.wide]: 72 },
    paddingInline: { default: space.gutter, [media.wide]: space.gutterWide },
    fontFamily: font.text,
    fontSize: size.s15,
    lineHeight: leading.l20,
  },
  brand: {
    display: 'flex',
    alignItems: 'center',
    gap: { default: 8, [media.wide]: 12 },
  },
  icon: {
    width: { default: 28, [media.wide]: 32 },
    height: { default: 28, [media.wide]: 32 },
  },
  name: {
    color: color.text,
    fontWeight: 600,
  },
  compact: {
    display: { default: 'block', [media.wide]: 'none' },
    paddingBlock: 6,
    paddingInline: 12,
    borderRadius: radius.round,
    backgroundColor: color.card,
    color: color.textBody,
    fontSize: size.s13,
    fontWeight: 500,
    lineHeight: leading.l16,
  },
  nav: {
    display: { default: 'none', [media.wide]: 'flex' },
    gap: { default: 24, [media.wide]: 32 },
  },
  link: {
    color: {
      default: color.textMuted,
      ':hover': color.text,
    },
    whiteSpace: 'nowrap',
  },
})
