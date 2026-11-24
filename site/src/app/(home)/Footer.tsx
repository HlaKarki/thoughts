import * as stylex from '@stylexjs/stylex'
import { AppIcon } from '@/components/AppIcon'
import { footer } from '@/content/footer'
import { color, font, leading, media, size, space, width } from '@/styles/tokens.stylex'

export function Footer() {
  return (
    <footer {...stylex.props(styles.footer)}>
      <div {...stylex.props(styles.inner)}>
        <div {...stylex.props(styles.about)}>
          <span {...stylex.props(styles.brand)}>
            <AppIcon size={20} decorative />
            {footer.brand}
          </span>
          <p>{footer.credit}</p>
        </div>
        <nav aria-label={footer.navLabel}>
          <ul {...stylex.props(styles.links)}>
            {footer.links.map((link) => (
              <li key={link.href}>
                <a href={link.href} {...stylex.props(styles.link)}>
                  {link.label}
                </a>
              </li>
            ))}
          </ul>
        </nav>
      </div>
    </footer>
  )
}

const styles = stylex.create({
  footer: {
    paddingTop: { default: space.sectionTop, [media.wide]: 120 },
    paddingBottom: { default: 40, [media.wide]: 48 },
    paddingInline: space.gutter,
    color: color.textMuted,
    fontFamily: font.text,
    fontSize: size.s13,
    lineHeight: leading.l16,
  },
  inner: {
    display: 'flex',
    flexDirection: { default: 'column', [media.wide]: 'row' },
    alignItems: { default: 'start', [media.wide]: 'center' },
    justifyContent: 'space-between',
    gap: 16,
    maxWidth: width.scene,
    marginInline: 'auto',
    paddingTop: { default: 24, [media.wide]: 32 },
    borderTopWidth: 1,
    borderTopStyle: 'solid',
    borderTopColor: color.hairline,
  },
  about: {
    display: 'flex',
    flexDirection: { default: 'column', [media.wide]: 'row' },
    alignItems: { default: 'start', [media.wide]: 'center' },
    gap: { default: 12, [media.wide]: 24 },
  },
  brand: {
    display: 'flex',
    alignItems: 'center',
    gap: 10,
    color: color.textBody,
    fontWeight: 600,
  },
  links: {
    display: 'flex',
    alignItems: 'center',
    gap: 24,
  },
  link: {
    color: { default: color.textMuted, ':hover': color.text },
  },
})
