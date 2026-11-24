import * as stylex from '@stylexjs/stylex'
import { BackForward, BrowserActions, Lock } from '@/components/Icons'
import { Photo } from '@/components/Photo'
import { hero } from '@/content/hero'
import { color, font, leading, radius, size, tracking } from '@/styles/tokens.stylex'

const page = hero.browser

export function BrowserWindow() {
  return (
    <div {...stylex.props(styles.window)}>
      <div {...stylex.props(styles.toolbar)}>
        <div {...stylex.props(styles.lights)}>
          <span {...stylex.props(styles.light, styles.red)} />
          <span {...stylex.props(styles.light, styles.yellow)} />
          <span {...stylex.props(styles.light, styles.green)} />
        </div>
        <BackForward xstyle={styles.toolIcon} dim={styles.toolIconDim} />
        <div {...stylex.props(styles.addressSlot)}>
          <div {...stylex.props(styles.address)}>
            <Lock xstyle={styles.toolIcon} />
            <span>{page.address}</span>
          </div>
        </div>
        <BrowserActions xstyle={styles.toolIcon} />
      </div>
      <div {...stylex.props(styles.page)}>
        <p {...stylex.props(styles.eyebrow)}>{page.eyebrow}</p>
        <p {...stylex.props(styles.title)}>{page.title}</p>
        <p {...stylex.props(styles.body)}>{page.intro}</p>
        <Photo src={page.photo} xstyle={styles.photo} />
        <div {...stylex.props(styles.section)}>
          <p {...stylex.props(styles.heading)}>{page.heading}</p>
          <p {...stylex.props(styles.paragraph)}>
            {page.paragraph.before}
            <span {...stylex.props(styles.selected)}>{page.paragraph.selected}</span>
            {page.paragraph.after}
          </p>
        </div>
      </div>
    </div>
  )
}

const styles = stylex.create({
  window: {
    position: 'absolute',
    top: 64,
    left: 64,
    display: 'flex',
    flexDirection: 'column',
    width: 792,
    height: 640,
    overflow: 'clip',
    borderRadius: radius.r16,
    borderWidth: 1,
    borderStyle: 'solid',
    borderColor: color.windowBorder,
    backgroundColor: color.windowBg,
    boxShadow: color.windowShadow,
  },
  toolbar: {
    display: 'flex',
    alignItems: 'center',
    flexShrink: 0,
    gap: 16,
    height: 52,
    paddingLeft: 20,
    paddingRight: 16,
    backgroundColor: color.toolbar,
    borderBottomWidth: 1,
    borderBottomStyle: 'solid',
    borderBottomColor: color.toolbarBorder,
  },
  lights: {
    display: 'flex',
    gap: 8,
  },
  light: {
    width: 12,
    height: 12,
    borderRadius: radius.r6,
  },
  red: { backgroundColor: color.trafficRed },
  yellow: { backgroundColor: color.trafficYellow },
  green: { backgroundColor: color.trafficGreen },
  toolIcon: {
    color: color.toolIcon,
  },
  toolIconDim: {
    color: color.toolIconDim,
  },
  addressSlot: {
    display: 'flex',
    justifyContent: 'center',
    flexGrow: 1,
    flexBasis: 0,
  },
  address: {
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'center',
    flexShrink: 0,
    gap: 6,
    width: 360,
    height: 32,
    borderRadius: radius.r16,
    backgroundColor: color.address,
    color: color.addressText,
    fontFamily: font.text,
    fontSize: size.s13,
    lineHeight: leading.l16,
  },
  page: {
    display: 'flex',
    flexDirection: 'column',
    flexGrow: 1,
    flexBasis: 0,
    gap: 16,
    overflow: 'clip',
    paddingInline: 116,
    paddingTop: 40,
    fontFamily: font.text,
  },
  eyebrow: {
    color: color.pageEyebrow,
    fontSize: size.s12,
    fontWeight: 500,
    lineHeight: leading.l16,
    letterSpacing: tracking.eyebrow,
    textTransform: 'uppercase',
  },
  title: {
    color: color.pageTitle,
    fontFamily: font.display,
    fontSize: size.s32,
    fontWeight: 700,
    lineHeight: leading.l40,
    letterSpacing: tracking.lead,
  },
  body: {
    color: color.pageBody,
    fontSize: size.s15,
    lineHeight: leading.l24,
  },
  photo: {
    height: 280,
    borderRadius: radius.r12,
    backgroundSize: '558px 372.1px',
    backgroundPosition: '0 -48px',
  },
  section: {
    display: 'flex',
    flexDirection: 'column',
    gap: 8,
  },
  heading: {
    color: color.pageTitle,
    fontFamily: font.display,
    fontSize: size.s20,
    fontWeight: 600,
    lineHeight: leading.l28,
  },
  paragraph: {
    color: color.pageBody,
    fontSize: size.s15,
    lineHeight: leading.l24,
  },
  selected: {
    paddingBlock: 3,
    backgroundColor: color.selection,
    color: color.selectionText,
  },
})
