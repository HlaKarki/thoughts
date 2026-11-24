import * as stylex from '@stylexjs/stylex'
import { GlassPanel } from '@/components/GlassPanel'
import { MoreDots, Search } from '@/components/Icons'
import { KeyHint } from '@/components/KeyHint'
import { Photo } from '@/components/Photo'
import { ThoughtRow } from '@/components/ThoughtRow'
import { hero } from '@/content/hero'
import { layout } from '@/styles/layout'
import { color, font, leading, media, motion, radius, size } from '@/styles/tokens.stylex'

const panel = hero.panel

const slideIn = stylex.keyframes({
  from: { translate: 'calc(100% + 16px) 0' },
})

export function HeroPanel() {
  return (
    <GlassPanel scale="full" xstyle={styles.panel}>
      <div {...stylex.props(styles.header)}>
        <div {...stylex.props(styles.search)}>
          <Search xstyle={styles.icon} />
          <span {...stylex.props(styles.placeholder)}>{panel.search}</span>
        </div>
        <span {...stylex.props(styles.menu)}>
          <MoreDots xstyle={styles.icon} />
        </span>
      </div>
      <ul {...stylex.props(styles.list)}>
        {panel.rows.map((row) =>
          row.kind === 'text' ? (
            <ThoughtRow
              key={row.text}
              time={row.time}
              done={row.done}
              xstyle={row.layout === 'wide' ? layout.wideFlex : row.layout === 'narrow' ? layout.narrowFlex : undefined}
            >
              {row.text}
            </ThoughtRow>
          ) : (
            <ThoughtRow key={row.note} time={row.time}>
              <Photo src={row.image} xstyle={styles.thumbnail}>
                <span {...stylex.props(styles.marker)} />
              </Photo>
              <span>{row.note}</span>
            </ThoughtRow>
          ),
        )}
      </ul>
      <div {...stylex.props(styles.composer)}>
        <div {...stylex.props(styles.input)}>
          <span {...stylex.props(styles.caret)} />
          <span {...stylex.props(styles.placeholder, styles.composerText)}>{panel.composer}</span>
        </div>
        <div {...stylex.props(styles.hints)}>
          {panel.hints.map((hint) => (
            <KeyHint key={hint.label} label={hint.label} keys={hint.keys} />
          ))}
        </div>
      </div>
    </GlassPanel>
  )
}

const styles = stylex.create({
  panel: {
    position: 'absolute',
    left: 904,
    top: { default: 106, [media.wide]: 40 },
    width: 360,
    height: { default: 812, [media.wide]: 744 },
    animationName: { default: null, [media.motion]: slideIn },
    animationDuration: motion.panelIn,
    animationDelay: motion.panelDelay,
    animationTimingFunction: motion.easeOut,
    animationFillMode: 'backwards',
  },
  header: {
    display: 'flex',
    alignItems: 'center',
    flexShrink: 0,
    gap: 8,
    paddingTop: 12,
    paddingBottom: 10,
    paddingInline: 12,
  },
  search: {
    display: 'flex',
    alignItems: 'center',
    flexGrow: 1,
    flexBasis: 0,
    gap: 7,
    height: 32,
    paddingInline: 10,
    borderRadius: radius.r16,
    backgroundColor: color.field,
  },
  icon: {
    color: color.fieldIcon,
  },
  placeholder: {
    color: color.placeholder,
    fontFamily: font.text,
    fontSize: size.s13,
    lineHeight: leading.l16,
  },
  menu: {
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'center',
    flexShrink: 0,
    width: 32,
    height: 32,
  },
  list: {
    display: 'flex',
    flexDirection: 'column',
    justifyContent: 'end',
    flexGrow: 1,
    flexBasis: 0,
    minHeight: 0,
    gap: 4,
    overflow: 'clip',
    paddingTop: 4,
    paddingInline: 12,
    paddingBottom: 8,
  },
  thumbnail: {
    width: 128,
    height: 104,
    borderRadius: radius.r8,
    borderWidth: 1,
    borderStyle: 'solid',
    borderColor: color.thumbBorder,
    backgroundOrigin: 'border-box',
    backgroundSize: '136px 149.5px',
    backgroundPosition: '0 -33px',
  },
  marker: {
    position: 'absolute',
    top: 6,
    left: 14,
    width: 98,
    height: 90,
    borderRadius: radius.r5,
    borderWidth: 1.5,
    borderStyle: 'solid',
    borderColor: color.marker,
  },
  composer: {
    display: 'flex',
    flexDirection: 'column',
    flexShrink: 0,
    gap: 8,
    paddingTop: 10,
    paddingInline: 12,
    paddingBottom: 12,
  },
  input: {
    display: 'flex',
    alignItems: 'center',
    flexShrink: 0,
    height: 38,
    paddingInline: 10,
    borderRadius: radius.r19,
    borderWidth: 1,
    borderStyle: 'solid',
    borderColor: color.composerBorder,
    backgroundColor: color.composer,
  },
  caret: {
    flexShrink: 0,
    width: 1.5,
    height: 16,
    backgroundColor: color.caret,
  },
  composerText: {
    paddingLeft: 1,
  },
  hints: {
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'end',
    flexShrink: 0,
    gap: 14,
    height: 16,
    paddingInline: 4,
  },
})
