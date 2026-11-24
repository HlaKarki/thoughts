import * as stylex from '@stylexjs/stylex'
import type { ReactNode } from 'react'
import { AppIcon } from '@/components/AppIcon'
import { AccessibilityGlyph, ClipboardGlyph, FolderGlyph } from '@/components/Icons'
import { features } from '@/content/features'
import { color, font, leading, media, radius, size } from '@/styles/tokens.stylex'
import { Tile } from './Tile'

const tile = features.privacy.tile

export function PrivacyTile() {
  return (
    <Tile label={tile.label}>
      <div {...stylex.props(styles.settings)}>
        <Group glyph={<AccessibilityGlyph />} label={tile.accessibility}>
          <div {...stylex.props(styles.row)}>
            <AppIcon size={20} decorative xstyle={styles.icon} />
            <span {...stylex.props(styles.label)}>{tile.app}</span>
            <Toggle />
          </div>
        </Group>
        <Group glyph={<ClipboardGlyph />} label={tile.paste}>
          <div {...stylex.props(styles.row)}>
            <AppIcon size={20} decorative xstyle={styles.icon} />
            <span {...stylex.props(styles.label)}>{tile.app}</span>
            <span {...stylex.props(styles.popup)}>
              {tile.pasteValue}
              <Chevrons />
            </span>
          </div>
        </Group>
        <Group glyph={<FolderGlyph />} label={tile.files}>
          <div {...stylex.props(styles.row)}>
            <AppIcon size={20} decorative xstyle={styles.icon} />
            <span {...stylex.props(styles.label)}>{tile.app}</span>
          </div>
          <span {...stylex.props(styles.divider)} />
          <div {...stylex.props(styles.row, styles.nested)}>
            <span {...stylex.props(styles.label)}>{tile.folder}</span>
            <Toggle />
          </div>
        </Group>
      </div>
    </Tile>
  )
}

type GroupProps = {
  readonly glyph: ReactNode
  readonly label: string
  readonly children: ReactNode
}

function Group({ glyph, label, children }: GroupProps) {
  return (
    <div {...stylex.props(styles.group)}>
      <div {...stylex.props(styles.groupHeader)}>
        <span {...stylex.props(styles.groupGlyph)}>{glyph}</span>
        <span {...stylex.props(styles.groupLabel)}>{label}</span>
      </div>
      <div {...stylex.props(styles.list)}>{children}</div>
    </div>
  )
}

function Chevrons() {
  return (
    <svg width="7" height="10" viewBox="0 0 7 10" aria-hidden>
      <path d="M1 3.6 3.5 1.2 6 3.6M1 6.4 3.5 8.8 6 6.4" fill="none" stroke="currentColor" strokeWidth="1.2" strokeLinecap="round" strokeLinejoin="round" />
    </svg>
  )
}

function Toggle() {
  return (
    <span {...stylex.props(styles.toggle)}>
      <span {...stylex.props(styles.knob)} />
    </span>
  )
}

const styles = stylex.create({
  settings: {
    position: 'absolute',
    top: { default: 66, [media.wide]: 30 },
    left: { default: 16, [media.wide]: 70 },
    display: 'flex',
    flexDirection: 'column',
    gap: { default: 16, [media.wide]: 12 },
    width: { default: 326, [media.wide]: 360 },
    fontFamily: font.text,
    fontSize: size.s13,
    lineHeight: leading.l16,
  },
  group: {
    display: 'flex',
    flexDirection: 'column',
    gap: 8,
  },
  groupHeader: {
    display: 'flex',
    alignItems: 'center',
    gap: 8,
    paddingLeft: 2,
  },
  groupGlyph: {
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'center',
    flexShrink: 0,
    width: 18,
    height: 18,
    borderRadius: radius.r5,
    backgroundColor: color.accent,
    color: color.onAccent,
  },
  groupLabel: {
    color: color.settingsGroup,
    fontWeight: 600,
  },
  list: {
    display: 'flex',
    flexDirection: 'column',
    overflow: 'clip',
    borderRadius: radius.r10,
    borderWidth: 1,
    borderStyle: 'solid',
    borderColor: color.settingsBorder,
    backgroundColor: color.settingsList,
    boxShadow: color.settingsShadow,
  },
  row: {
    display: 'flex',
    alignItems: 'center',
    flexShrink: 0,
    gap: 10,
    height: 38,
    paddingInline: 12,
  },
  nested: {
    paddingLeft: 42,
  },
  icon: {
    width: 20,
    height: 20,
    overflow: 'clip',
    borderRadius: radius.r5,
  },
  popup: {
    display: 'flex',
    alignItems: 'center',
    gap: 6,
    flexShrink: 0,
    color: color.textMuted,
  },
  label: {
    flexGrow: 1,
    flexBasis: 0,
    color: color.rowText,
  },
  divider: {
    display: 'block',
    flexShrink: 0,
    height: 1,
    backgroundColor: color.settingsDivider,
  },
  toggle: {
    display: 'flex',
    alignItems: 'center',
    flexShrink: 0,
    width: 28,
    height: 16,
    paddingInline: 2,
    justifyContent: 'end',
    borderRadius: radius.r8,
    backgroundColor: color.accent,
  },
  knob: {
    flexShrink: 0,
    width: 12,
    height: 12,
    borderRadius: radius.r6,
    backgroundColor: color.knob,
  },
})
