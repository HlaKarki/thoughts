import * as stylex from '@stylexjs/stylex'

type IconProps = {
  readonly xstyle?: stylex.StyleXStyles
}

function svgProps(width: number, height: number, viewBox: string, xstyle?: stylex.StyleXStyles) {
  return {
    width,
    height,
    viewBox,
    fill: 'none',
    'aria-hidden': true,
    ...stylex.props(styles.icon, xstyle),
  }
}

export function AppleLogo({ xstyle }: IconProps) {
  return (
    <svg {...svgProps(14, 16, '0 0 24 24', xstyle)}>
      <path
        fill="currentColor"
        d="M12.152 6.896c-.948 0-2.415-1.078-3.96-1.04-2.04.027-3.91 1.183-4.961 3.014-2.117 3.675-.546 9.103 1.519 12.09 1.013 1.454 2.208 3.09 3.792 3.039 1.52-.065 2.09-.987 3.935-.987 1.831 0 2.35.987 3.96.948 1.637-.026 2.676-1.48 3.676-2.948 1.156-1.688 1.636-3.325 1.662-3.415-.039-.013-3.182-1.221-3.22-4.857-.026-3.04 2.48-4.494 2.597-4.559-1.429-2.09-3.623-2.324-4.39-2.376-2-.156-3.675 1.090-4.61 1.090zM15.53 3.83c.843-1.012 1.4-2.427 1.245-3.83-1.207.052-2.662.805-3.532 1.818-.78.896-1.454 2.338-1.273 3.714 1.338.104 2.715-.688 3.559-1.701"
      />
    </svg>
  )
}

export function Battery({ xstyle, outline }: IconProps & { readonly outline: stylex.StyleXStyles }) {
  return (
    <svg {...svgProps(24, 12, '0 0 24 12', xstyle)}>
      <g {...stylex.props(outline)}>
        <rect x="0.5" y="0.5" width="20" height="11" rx="3" stroke="currentColor" />
        <path d="M22 4v4c.8-.3 1.3-1.1 1.3-2s-.5-1.7-1.3-2z" fill="currentColor" />
      </g>
      <rect x="2" y="2" width="14" height="8" rx="1.5" fill="currentColor" />
    </svg>
  )
}

export function ThoughtsCaret({ xstyle }: IconProps) {
  return (
    <svg {...svgProps(18, 18, '0 0 18 18', xstyle)}>
      <rect x="0" y="12" width="13" height="4" rx="2" fill="currentColor" />
      <rect x="15" y="2" width="3" height="14" rx="1.5" fill="currentColor" />
    </svg>
  )
}

export function Wifi({ xstyle }: IconProps) {
  return (
    <svg {...svgProps(16, 12, '0 0 16 12', xstyle)}>
      <path d="M8 11.2 10.3 8.9a3.3 3.3 0 0 0-4.6 0L8 11.2Z" fill="currentColor" />
      <path
        d="M3.9 7.1a5.8 5.8 0 0 1 8.2 0M1.4 4.6a9.4 9.4 0 0 1 13.2 0"
        stroke="currentColor"
        strokeWidth="1.5"
        strokeLinecap="round"
      />
    </svg>
  )
}

export function Search({ xstyle, size = 14, strokeWidth = 1.5 }: IconProps & { readonly size?: number; readonly strokeWidth?: number }) {
  return (
    <svg {...svgProps(size, size, '0 0 14 14', xstyle)}>
      <circle cx="6" cy="6" r="4.5" stroke="currentColor" strokeWidth={strokeWidth} />
      <path d="M9.5 9.5 12.5 12.5" stroke="currentColor" strokeWidth={strokeWidth} strokeLinecap="round" />
    </svg>
  )
}

export function ClearSearch({ xstyle, size = 14 }: IconProps & { readonly size?: number }) {
  return (
    <svg {...svgProps(size, size, '0 0 14 14', xstyle)}>
      <path
        fill="currentColor"
        fillRule="evenodd"
        d="M7 0a7 7 0 1 1 0 14A7 7 0 0 1 7 0ZM8.66 4.28L9.72 5.34L8.06 7L9.72 8.66L8.66 9.72L7 8.06L5.34 9.72L4.28 8.66L5.94 7L4.28 5.34L5.34 4.28L7 5.94Z"
      />
    </svg>
  )
}

export function ControlCenter({ xstyle }: IconProps) {
  return (
    <svg {...svgProps(16, 14, '0 0 16 14', xstyle)}>
      <rect x=".75" y=".75" width="14.5" height="5" rx="2.5" stroke="currentColor" strokeWidth="1.3" />
      <circle cx="12.7" cy="3.25" r="1.6" fill="currentColor" />
      <rect x=".75" y="8.25" width="14.5" height="5" rx="2.5" stroke="currentColor" strokeWidth="1.3" />
      <circle cx="3.3" cy="10.75" r="1.6" fill="currentColor" />
    </svg>
  )
}

export function BackForward({ xstyle, dim }: IconProps & { readonly dim: stylex.StyleXStyles }) {
  return (
    <svg {...svgProps(56, 16, '0 0 56 16', xstyle)}>
      <path d="M14 3 9 8l5 5" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round" />
      <path
        d="M38 3l5 5-5 5"
        stroke="currentColor"
        strokeWidth="1.6"
        strokeLinecap="round"
        strokeLinejoin="round"
        {...stylex.props(dim)}
      />
    </svg>
  )
}

export function Lock({ xstyle }: IconProps) {
  return (
    <svg {...svgProps(10, 12, '0 0 10 12', xstyle)}>
      <rect x="1" y="5" width="8" height="6.5" rx="1.5" fill="currentColor" />
      <path d="M2.8 5V3.6a2.2 2.2 0 0 1 4.4 0V5" stroke="currentColor" strokeWidth="1.3" />
    </svg>
  )
}

export function BrowserActions({ xstyle }: IconProps) {
  return (
    <svg {...svgProps(72, 16, '0 0 72 16', xstyle)}>
      <g stroke="currentColor" strokeWidth="1.5">
        <path d="M8 1.5v9M5 4.2 8 1.2l3 3" strokeLinecap="round" strokeLinejoin="round" />
        <path d="M5.5 7H4a1.5 1.5 0 0 0-1.5 1.5v5A1.5 1.5 0 0 0 4 15h8a1.5 1.5 0 0 0 1.5-1.5v-5A1.5 1.5 0 0 0 12 7h-1.5" />
        <path d="M36 2v12M30 8h12" strokeLinecap="round" />
        <rect x="58.75" y="1.75" width="10.5" height="10.5" rx="2" />
        <path d="M61.5 14.5h7a2 2 0 0 0 2-2v-7" strokeLinecap="round" />
      </g>
    </svg>
  )
}

export function MoreDots({ xstyle, width = 16, height = 4, r = 1.6 }: IconProps & { readonly width?: number; readonly height?: number; readonly r?: number }) {
  return (
    <svg {...svgProps(width, height, '0 0 16 4', xstyle)}>
      <circle cx="2" cy="2" r={r} fill="currentColor" />
      <circle cx="8" cy="2" r={r} fill="currentColor" />
      <circle cx="14" cy="2" r={r} fill="currentColor" />
    </svg>
  )
}

export function AccessibilityGlyph({ xstyle }: IconProps) {
  return (
    <svg {...svgProps(12, 12, '0 0 12 12', xstyle)}>
      <circle cx="6" cy="2.2" r="1.3" fill="currentColor" />
      <path
        d="M2 4.3 6 5.1 10 4.3M6 5.1 6 7.4M6 7.4 4.2 10.6M6 7.4 7.8 10.6"
        stroke="currentColor"
        strokeWidth="1.3"
        strokeLinecap="round"
        strokeLinejoin="round"
      />
    </svg>
  )
}

export function ClipboardGlyph({ xstyle }: IconProps) {
  return (
    <svg {...svgProps(12, 12, '0 0 12 12', xstyle)}>
      <rect x="2.4" y="2.4" width="7.2" height="8.4" rx="1.2" fill="none" stroke="currentColor" strokeWidth="1.2" />
      <rect x="4" y="1.2" width="4" height="2.4" rx="0.8" fill="currentColor" />
    </svg>
  )
}

export function FolderGlyph({ xstyle }: IconProps) {
  return (
    <svg {...svgProps(12, 12, '0 0 12 12', xstyle)}>
      <path
        fill="currentColor"
        d="M1.5 3.2C1.5 2.8 1.8 2.5 2.2 2.5L4.6 2.5 5.6 3.6 9.8 3.6C10.2 3.6 10.5 3.9 10.5 4.3L10.5 9C10.5 9.4 10.2 9.7 9.8 9.7L2.2 9.7C1.8 9.7 1.5 9.4 1.5 9Z"
      />
    </svg>
  )
}

const styles = stylex.create({
  icon: {
    display: 'block',
    flexShrink: 0,
    overflow: 'visible',
  },
})
