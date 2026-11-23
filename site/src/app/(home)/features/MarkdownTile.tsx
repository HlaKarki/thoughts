import * as stylex from '@stylexjs/stylex'
import { Collapse } from '@/components/Collapse'
import { MiniBarsRow, MiniPanel, MiniRow, MiniThumbnail } from '@/components/MiniPanel'
import { MiniWindow } from '@/components/MiniWindow'
import { features } from '@/content/features'
import { site } from '@/content/site'
import { loop } from '@/styles/loop'
import { color, font, leading, media, size } from '@/styles/tokens.stylex'
import { Tile } from './Tile'

const tile = features.markdown.tile

const typing = stylex.keyframes({
  '0%': { opacity: 1, maxWidth: '12ch' },
  '4%': { opacity: 0, maxWidth: '12ch' },
  '4.01%, 11%': { opacity: 1, maxWidth: '0ch', animationTimingFunction: 'steps(12, end)' },
  '26%, 100%': { opacity: 1, maxWidth: '12ch' },
})

const grow = stylex.keyframes({
  '0%': { gridTemplateRows: '1fr', opacity: 1 },
  '4%, 31%': { gridTemplateRows: '0fr', opacity: 0 },
  '34%, 100%': { gridTemplateRows: '1fr', opacity: 1 },
})

export function MarkdownTile() {
  return (
    <Tile label={tile.label}>
      <MiniWindow title={tile.fileName} xstyle={styles.window}>
        <div {...stylex.props(styles.file)}>
          <span {...stylex.props(styles.text)}>{tile.frontMatter}</span>
          <span {...stylex.props(styles.edited)}>
            <span {...stylex.props(styles.text, styles.typed, loop.short, styles.typing)}>{tile.typed}</span>
            <span {...stylex.props(styles.caret)} />
          </span>
        </div>
      </MiniWindow>
      <MiniPanel xstyle={styles.panel}>
        <MiniBarsRow widths={[100, 44]} />
        <MiniBarsRow widths={[76]} />
        <MiniRow time={tile.time}>
          <MiniThumbnail src={site.photos.cat} />
          <span {...stylex.props(styles.note)}>
            <span>{tile.note}</span>
            <Collapse xstyle={[loop.short, styles.growing]}>
              <span>{tile.typed}</span>
            </Collapse>
          </span>
        </MiniRow>
        <MiniBarsRow widths={[100, 44]} />
      </MiniPanel>
    </Tile>
  )
}

const styles = stylex.create({
  window: {
    top: { default: 16, [media.wide]: 24 },
    left: { default: 16, [media.wide]: 24 },
    width: { default: 300, [media.wide]: 284 },
    height: { default: 300, [media.wide]: 272 },
  },
  file: {
    display: 'flex',
    flexDirection: 'column',
    paddingBlock: 10,
    paddingLeft: 12,
    paddingRight: 8,
  },
  text: {
    color: color.rowText,
    fontFamily: font.mono,
    fontSize: size.s11,
    lineHeight: leading.l16,
    whiteSpace: 'pre',
  },
  edited: {
    display: 'flex',
    alignItems: 'center',
    flexShrink: 0,
    gap: 1,
    height: 16,
  },
  typed: {
    overflow: 'clip',
  },
  typing: {
    animationName: { default: null, [media.motion]: typing },
  },
  caret: {
    flexShrink: 0,
    width: 1,
    height: 13,
    backgroundColor: color.caret,
  },
  panel: {
    top: { default: 72, [media.wide]: 24 },
    left: { default: 182, [media.wide]: 316 },
    width: 160,
    height: { default: 312, [media.wide]: 272 },
  },
  note: {
    display: 'flex',
    flexDirection: 'column',
    paddingTop: 4,
  },
  growing: {
    animationName: { default: null, [media.motion]: grow },
  },
})
