import * as stylex from '@stylexjs/stylex'
import { Keycap } from '@/components/Keycap'
import { keyboard } from '@/content/keyboard'
import { layout } from '@/styles/layout'
import { color, font, leading, media, size, space } from '@/styles/tokens.stylex'
import { SectionIntro } from './SectionIntro'

type Group = (typeof keyboard)['anywhere']

export function Keyboard() {
  return (
    <section {...stylex.props(layout.column, styles.section)}>
      <SectionIntro heading={keyboard.heading} muted={keyboard.headingMuted} body={keyboard.body} />
      <div {...stylex.props(styles.columns)}>
        <div {...stylex.props(styles.column, styles.stack)}>
          <ShortcutGroup group={keyboard.anywhere} />
          <ShortcutGroup group={keyboard.panel} />
          <p {...stylex.props(layout.wideBlock, styles.note)}>{keyboard.note}</p>
        </div>
        <div {...stylex.props(styles.column)}>
          <ShortcutGroup group={keyboard.selected} />
        </div>
        <p {...stylex.props(layout.narrowBlock, styles.note)}>{keyboard.note}</p>
      </div>
    </section>
  )
}

function ShortcutGroup({ group }: { readonly group: Group }) {
  return (
    <div {...stylex.props(styles.group)}>
      <h3 {...stylex.props(styles.title)}>{group.title}</h3>
      <dl {...stylex.props(styles.list)}>
        {group.shortcuts.map((shortcut) => (
          <div key={shortcut.action} {...stylex.props(styles.row)}>
            <dt {...stylex.props(styles.action)}>{shortcut.action}</dt>
            <dd {...stylex.props(styles.keys)}>
              {shortcut.keys.map((key) => (
                <Keycap key={key} variant="table">
                  {key}
                </Keycap>
              ))}
            </dd>
          </div>
        ))}
      </dl>
    </div>
  )
}

const styles = stylex.create({
  section: {
    display: 'flex',
    flexDirection: 'column',
    gap: { default: 32, [media.wide]: 48 },
    paddingTop: { default: space.sectionTop, [media.wide]: space.sectionTopWide },
  },
  columns: {
    display: 'flex',
    flexDirection: { default: 'column', [media.wide]: 'row' },
    alignItems: { default: 'stretch', [media.wide]: 'start' },
    gap: { default: 32, [media.wide]: 40 },
  },
  column: {
    display: 'flex',
    flexDirection: 'column',
    flexShrink: 0,
    width: { default: '100%', [media.wide]: 500 },
  },
  stack: {
    gap: 32,
  },
  group: {
    display: 'flex',
    flexDirection: 'column',
  },
  title: {
    paddingBottom: 8,
    borderBottomWidth: 1,
    borderBottomStyle: 'solid',
    borderBottomColor: color.hairline,
    color: color.textMuted,
    fontFamily: font.text,
    fontSize: size.s13,
    fontWeight: 600,
    lineHeight: leading.l16,
  },
  list: {
    display: 'flex',
    flexDirection: 'column',
    margin: 0,
  },
  row: {
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'space-between',
    flexShrink: 0,
    gap: 16,
    height: 44,
    borderBottomWidth: 1,
    borderBottomStyle: 'solid',
    borderBottomColor: color.hairline,
  },
  action: {
    color: color.textBody,
    fontFamily: font.text,
    fontSize: size.s15,
    lineHeight: leading.l20,
  },
  keys: {
    display: 'flex',
    alignItems: 'center',
    flexShrink: 0,
    gap: 4,
    margin: 0,
  },
  note: {
    color: color.textMuted,
    fontFamily: font.text,
    fontSize: size.s15,
    lineHeight: leading.l24,
  },
})
