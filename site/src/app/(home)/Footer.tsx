import * as stylex from '@stylexjs/stylex'
import { AppIcon } from '@/components/AppIcon'
import { footer } from '@/content/footer'
import { color, font, leading, media, size, space, width } from '@/styles/tokens.stylex'

export function Footer() {
  return (
    <footer {...stylex.props(styles.footer)}>
      <div {...stylex.props(styles.inner)}>
        <div {...stylex.props(styles.top)}>
          <div {...stylex.props(styles.about)}>
            <a href="/" {...stylex.props(styles.brand)}>
              <AppIcon size={28} decorative />
              {footer.brand}
            </a>
            <p {...stylex.props(styles.tagline)}>{footer.tagline}</p>
          </div>
          <nav aria-label={footer.navLabel} {...stylex.props(styles.columns)}>
            {footer.columns.map((column) => (
              <div key={column.heading} {...stylex.props(styles.column)}>
                <h2 {...stylex.props(styles.heading)}>{column.heading}</h2>
                <ul {...stylex.props(styles.links)}>
                  {column.links.map((link) => (
                    <li key={link.href}>
                      <a href={link.href} {...stylex.props(styles.link)}>
                        {link.label}
                      </a>
                    </li>
                  ))}
                </ul>
              </div>
            ))}
          </nav>
        </div>
        <div {...stylex.props(styles.bottom)}>
          <p>
            {footer.maker.before}
            <a href={footer.maker.link.href} {...stylex.props(styles.link)}>
              {footer.maker.link.label}
            </a>
            .
          </p>
          <p>{footer.credit}</p>
        </div>
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
    flexDirection: 'column',
    gap: { default: 40, [media.wide]: 56 },
    maxWidth: width.scene,
    marginInline: 'auto',
    paddingTop: { default: 32, [media.wide]: 48 },
    borderTopWidth: 1,
    borderTopStyle: 'solid',
    borderTopColor: color.hairline,
  },
  top: {
    display: 'grid',
    gridTemplateColumns: { default: 'repeat(2, minmax(0, 1fr))', [media.wide]: '2fr repeat(3, 1fr)' },
    gap: { default: 32, [media.wide]: 48 },
  },
  about: {
    display: 'flex',
    flexDirection: 'column',
    gap: 12,
    gridColumn: { default: '1 / -1', [media.wide]: 'auto' },
  },
  brand: {
    display: 'flex',
    alignItems: 'center',
    gap: 10,
    color: color.text,
    fontSize: size.s17,
    fontWeight: 600,
    lineHeight: leading.l24,
    marginTop: -6,
  },
  tagline: {
    maxWidth: 260,
    color: color.textMuted,
    lineHeight: leading.l20,
  },
  columns: {
    display: 'contents',
  },
  column: {
    display: 'flex',
    flexDirection: 'column',
    gap: 12,
  },
  heading: {
    color: color.textBody,
    fontSize: size.s13,
    fontWeight: 600,
    lineHeight: leading.l16,
  },
  links: {
    display: 'flex',
    flexDirection: 'column',
    gap: 10,
  },
  link: {
    color: { default: color.textMuted, ':hover': color.text },
  },
  bottom: {
    display: 'flex',
    flexDirection: { default: 'column', [media.wide]: 'row' },
    justifyContent: 'space-between',
    gap: 8,
    paddingTop: { default: 20, [media.wide]: 24 },
    borderTopWidth: 1,
    borderTopStyle: 'solid',
    borderTopColor: color.hairline,
  },
})
