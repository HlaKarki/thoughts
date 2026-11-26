import * as stylex from '@stylexjs/stylex'

const DARK = '@media (prefers-color-scheme: dark)'

export const media = stylex.defineConsts({
  wide: '@media (min-width: 1100px)',
  motion: '@media (prefers-reduced-motion: no-preference)',
})

export const font = stylex.defineConsts({
  display: '"SF Pro Display", -apple-system, BlinkMacSystemFont, system-ui, sans-serif',
  text: '"SF Pro Text", -apple-system, BlinkMacSystemFont, system-ui, sans-serif',
  mono: 'Menlo, ui-monospace, monospace',
})

export const size = stylex.defineConsts({
  s10: '10px',
  s11: '11px',
  s12: '12px',
  s13: '13px',
  s14: '14px',
  s15: '15px',
  s17: '17px',
  s20: '20px',
  s24: '24px',
  s28: '28px',
  s32: '32px',
  s40: '40px',
})

export const leading = stylex.defineConsts({
  l15: '15px',
  l16: '16px',
  l18: '18px',
  l20: '20px',
  l24: '24px',
  l26: '26px',
  l28: '28px',
  l32: '32px',
  l36: '36px',
  l40: '40px',
  l48: '48px',
})

export const tracking = stylex.defineConsts({
  display: '-0.015em',
  lead: '-0.01em',
  leadNarrow: '-0.005em',
  eyebrow: '0.04em',
})

export const space = stylex.defineConsts({
  gutter: '16px',
  gutterWide: '80px',
  sectionTop: '96px',
  sectionTopWide: '160px',
})

export const width = stylex.defineConsts({
  column: '592px',
  columnWide: '1072px',
  intro: '792px',
  scene: '1280px',
})

export const radius = stylex.defineConsts({
  r2: '2px',
  r3: '3px',
  r4: '4px',
  r5: '5px',
  r6: '6px',
  r7: '7px',
  r8: '8px',
  r10: '10px',
  r11: '11px',
  r12: '12px',
  r14: '14px',
  r16: '16px',
  r19: '19px',
  r20: '20px',
  r22: '22px',
  r24: '24px',
  round: '999px',
})

export const motion = stylex.defineConsts({
  easeOut: 'cubic-bezier(0.16, 1, 0.3, 1)',
  easeIn: 'cubic-bezier(0.42, 0, 1, 1)',
  easeInOut: 'cubic-bezier(0.645, 0.045, 0.355, 1)',
  appEaseOut: 'cubic-bezier(0, 0, 0.58, 1)',
  steady: 'linear',
  atOnce: 'step-end',
})

export const color = stylex.defineVars({
  pageBg: { default: '#FFFFFF', [DARK]: '#0E0E0E' },
  text: { default: '#1D1D1F', [DARK]: '#F2F2F2' },
  textBody: { default: '#1D1D1F', [DARK]: '#E6E6E6' },
  textMuted: { default: '#6E6E73', [DARK]: '#8E8E93' },
  textCode: { default: '#424245', [DARK]: '#C7C7CC' },
  hairline: { default: '#00000014', [DARK]: '#FFFFFF14' },
  accent: { default: '#007AFF', [DARK]: '#0A84FF' },
  onAccent: '#FFFFFF',
  card: { default: '#F5F5F7', [DARK]: '#141414' },
  inset: { default: '#FFFFFF', [DARK]: '#0E0E0E' },
  keycap: { default: '#EEEEEE', [DARK]: '#333333' },
  keycapText: { default: '#6E6E6E', [DARK]: '#A0A0A0' },

  iconShadow: { default: '#00000033', [DARK]: '#00000080' },

  menuText: { default: '#000000', [DARK]: '#FFFFFF' },
  menuBatteryOutline: { default: '#000000', [DARK]: '#FFFFFF8C' },

  windowBg: { default: '#FFFFFF', [DARK]: '#1C1C1E' },
  windowBorder: { default: '#00000026', [DARK]: '#FFFFFF1F' },
  windowShadow: {
    default: '#0000001A 0px 1px 2px, #00000033 0px 24px 64px',
    [DARK]: '#0000004D 0px 1px 2px, #00000066 0px 24px 64px',
  },
  windowShadowMini: {
    default: '#0000001A 0px 1px 2px, #00000033 0px 12px 32px',
    [DARK]: '#0000004D 0px 1px 2px, #00000066 0px 12px 32px',
  },
  toolbar: { default: '#F6F6F6', [DARK]: '#262628' },
  toolbarBorder: { default: '#0000001A', [DARK]: '#00000080' },
  titleBarBorder: { default: '#0000001A', [DARK]: 'transparent' },
  titleText: { default: '#6E6E73', [DARK]: '#A0A0A0' },
  titleTextStrong: { default: '#3A3A3C', [DARK]: '#E6E6E6' },
  trafficRed: '#FF5F57',
  trafficYellow: '#FEBC2E',
  trafficGreen: '#28C840',
  toolIcon: { default: '#6E6E73', [DARK]: '#A0A0A0' },
  toolIconDim: { default: '#C7C7CC', [DARK]: '#5E5E5E' },
  address: { default: '#0000000D', [DARK]: '#FFFFFF12' },
  addressMini: { default: '#0000000D', [DARK]: '#FFFFFF14' },
  addressText: { default: '#1D1D1F', [DARK]: '#E6E6E6' },

  pageEyebrow: { default: '#6E6E73', [DARK]: '#8E8E93' },
  pageTitle: { default: '#1D1D1F', [DARK]: '#F2F2F2' },
  pageBody: { default: '#424245', [DARK]: '#B4B4B8' },
  selection: { default: '#007AFF40', [DARK]: '#0A84FF66' },
  selectionText: { default: '#1D1D1F', [DARK]: '#F2F2F2' },
  selectionTextMini: { default: '#151515', [DARK]: '#F2F2F2' },

  panel: { default: '#FFFFFFB3', [DARK]: '#1E1E1EA6' },
  panelBorder: { default: '#FFFFFFA6', [DARK]: '#FFFFFF26' },
  panelShadow: {
    default: '#FFFFFFCC 0px 1px 0px inset, #0000000F 0px 1px 2px, #0000002E 0px 18px 48px',
    [DARK]: '#FFFFFF26 0px 1px 0px inset, #0000004D 0px 1px 2px, #00000080 0px 18px 48px',
  },
  panelShadowMini: {
    default: '#FFFFFFCC 0px 1px 0px inset, #0000000F 0px 1px 2px, #0000002E 0px 12px 32px',
    [DARK]: '#FFFFFF26 0px 1px 0px inset, #0000004D 0px 1px 2px, #00000080 0px 12px 32px',
  },
  field: { default: '#0000000D', [DARK]: '#FFFFFF14' },
  fieldIcon: '#8E8E93',
  placeholder: '#8A8A8A',
  rowText: { default: '#151515', [DARK]: '#E6E6E6' },
  rowDone: { default: '#A0A0A0', [DARK]: '#5E5E5E' },
  rowTime: '#8A8A8A',
  composer: { default: '#FFFFFF59', [DARK]: '#FFFFFF0D' },
  composerBorder: { default: '#00000014', [DARK]: '#FFFFFF1F' },
  caret: { default: '#151515', [DARK]: '#E6E6E6' },
  thumbBorder: { default: '#00000012', [DARK]: '#FFFFFF14' },
  marker: '#FF3B30',
  notice: '#FFFFFF',
  noticeEyebrow: '#6E6E73',
  noticeHeading: '#1D1D1F',
  noticeBody: '#424245',

  bar: { default: '#00000026', [DARK]: '#FFFFFF33' },
  barDim: { default: '#00000012', [DARK]: '#FFFFFF14' },
  barTime: { default: '#00000017', [DARK]: '#FFFFFF1F' },
  barStrong: { default: '#00000059', [DARK]: '#FFFFFF66' },
  barHeading: { default: '#0000004D', [DARK]: '#FFFFFF59' },
  barLine: { default: '#0000001F', [DARK]: '#FFFFFF2E' },
  barField: { default: '#0000001F', [DARK]: '#FFFFFF26' },

  chip: { default: '#FFFFFF', [DARK]: '#2A2A2A' },
  chipBorder: { default: '#EBEBEB', [DARK]: '#444444' },
  chipShadow: {
    default: '#0000000F 0px 1px 2px, #00000026 0px 8px 20px',
    [DARK]: '#0000004D 0px 1px 2px, #00000066 0px 8px 20px',
  },
  chipSlot: { default: '#EEEEEE', [DARK]: '#3A3A3A' },
  chipTitle: { default: '#151515', [DARK]: '#E6E6E6' },
  chipSubtitle: { default: '#6E6E6E', [DARK]: '#A0A0A0' },

  key: { default: '#FFFFFF', [DARK]: '#2A2A2A' },
  keyBorder: { default: '#D1D1D6', [DARK]: '#444444' },
  keyShadow: { default: '#0000001F 0px 1px 0px', [DARK]: '#00000066 0px 1px 0px' },
  keyText: { default: '#3A3A3C', [DARK]: '#E6E6E6' },

  capture: '#FFFFFF14',
  captureBorder: '#FFFFFFCC',
  cursorBlock: { default: '#00000080', [DARK]: '#E6E6E6B3' },

  settingsList: { default: '#FFFFFF', [DARK]: '#1C1C1E' },
  settingsBorder: { default: '#0000001A', [DARK]: '#FFFFFF1F' },
  settingsShadow: {
    default: '#0000000F 0px 1px 2px, #00000026 0px 12px 32px',
    [DARK]: '#0000004D 0px 1px 2px, #00000066 0px 12px 32px',
  },
  settingsGroup: { default: '#1D1D1F', [DARK]: '#E6E6E6' },
  settingsDivider: { default: '#0000000F', [DARK]: '#FFFFFF14' },
  knob: '#FFFFFF',
})

export const scene = stylex.defineVars({
  wallpaper: {
    default:
      'radial-gradient(ellipse 60% 55% at 16% 8% in oklab, #C4BCDC 0%, #C4BCDC00 70%), radial-gradient(ellipse 55% 60% at 82% 56% in oklab, #E6BEAA 0%, #E6BEAA00 70%), radial-gradient(ellipse 70% 50% at 28% 100% in oklab, #7F8459 0%, #7F845900 75%), linear-gradient(in oklab 180deg, #ABA3C4 0%, #D3AFA3 52%, #8A8962 100%)',
    [DARK]:
      'radial-gradient(ellipse 60% 55% at 16% 8% in oklab, #A39BBE 0%, #A39BBE00 70%), radial-gradient(ellipse 55% 60% at 82% 56% in oklab, #C99C88 0%, #C99C8800 70%), radial-gradient(ellipse 70% 50% at 28% 100% in oklab, #4C5233 0%, #4C523300 75%), linear-gradient(in oklab 180deg, #827A9C 0%, #B08C84 52%, #5F5E3E 100%)',
  },
  tile: {
    default:
      'radial-gradient(ellipse 60% 55% at 16% 8% in oklab, #C4BCDC 0%, #C4BCDC00 70%), radial-gradient(ellipse 55% 60% at 82% 56% in oklab, #E6BEAA 0%, #E6BEAA00 70%), radial-gradient(ellipse 70% 50% at 28% 100% in oklab, #7F8459 0%, #7F845900 75%), linear-gradient(in oklab 180deg, #ABA3C4 0%, #D3AFA3 52%, #8A8962 100%)',
    [DARK]:
      'linear-gradient(#00000066, #00000066), radial-gradient(ellipse 60% 55% at 16% 8% in oklab, #A39BBE 0%, #A39BBE00 70%), radial-gradient(ellipse 55% 60% at 82% 56% in oklab, #C99C88 0%, #C99C8800 70%), radial-gradient(ellipse 70% 50% at 28% 100% in oklab, #4C5233 0%, #00000000 75%), linear-gradient(in oklab 180deg, #827A9C 0%, #B08C84 52%, #5F5E3E 100%)',
  },
})
