import * as stylex from '@stylexjs/stylex'
import type { ReactNode } from 'react'
import { AppIcon } from '@/components/AppIcon'
import { AccessibilityGlyph, FolderGlyph } from '@/components/Icons'
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
            <Toggle on />
          </div>
          <span {...stylex.props(styles.divider)} />
          <div {...stylex.props(styles.row)}>
            <span {...stylex.props(styles.icon, styles.placeholderIcon)} />
            <span {...stylex.props(styles.placeholder)}>
              <span {...stylex.props(styles.placeholderBar)} />
            </span>
            <Toggle on={false} />
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
            <Toggle on />
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

function Toggle({ on }: { readonly on: boolean }) {
  return (
    <span {...stylex.props(styles.toggle, on ? styles.toggleOn : styles.toggleOff)}>
      <span {...stylex.props(styles.knob, !on && styles.knobOff)} />
    </span>
  )
}

const styles = stylex.create({
  settings: {
    position: 'absolute',
    top: { default: 85, [media.wide]: 45 },
    left: { default: 16, [media.wide]: 70 },
    display: 'flex',
    flexDirection: 'column',
    gap: 20,
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
  placeholderIcon: {
    flexShrink: 0,
    backgroundColor: color.placeholderIcon,
  },
  label: {
    flexGrow: 1,
    flexBasis: 0,
    color: color.rowText,
  },
  placeholder: {
    display: 'flex',
    flexGrow: 1,
    flexBasis: 0,
  },
  placeholderBar: {
    flexShrink: 0,
    width: 72,
    height: 5,
    borderRadius: radius.r3,
    backgroundColor: color.placeholderBar,
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
    borderRadius: radius.r8,
  },
  toggleOn: {
    justifyContent: 'end',
    backgroundColor: color.accent,
  },
  toggleOff: {
    backgroundColor: color.toggleOff,
  },
  knob: {
    flexShrink: 0,
    width: 12,
    height: 12,
    borderRadius: radius.r6,
    backgroundColor: color.knob,
  },
  knobOff: {
    backgroundColor: color.knobOff,
  },
})
