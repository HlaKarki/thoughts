import * as stylex from '@stylexjs/stylex'
import { Collapse } from '@/components/Collapse'
import { MiniBarsRow, MiniPanel, MiniRow } from '@/components/MiniPanel'
import { MiniWindow } from '@/components/MiniWindow'
import { TypedText } from '@/components/TypedText'
import { features } from '@/content/features'
import { loop } from '@/styles/loop'
import { color, font, leading, media, size } from '@/styles/tokens.stylex'
import { reveal } from '@/styles/sequence.stylex'
import { Tile } from './Tile'

const tile = features.markdown.tile

const typing = stylex.keyframes({
  '0%': { opacity: 1, maxWidth: reveal.widthShown },
  '4%': { opacity: 0, maxWidth: reveal.widthShown },
  '4.01%, 11%': { opacity: 1, maxWidth: reveal.widthHidden },
  '26%, 100%': { opacity: 1, maxWidth: reveal.widthShown },
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
          <span {...stylex.props(styles.text, styles.edited)}>
            <TypedText text={tile.typed} wrapWords charXstyle={[loop.short, styles.typing]} />
            <span {...stylex.props(styles.caret)} />
          </span>
        </div>
      </MiniWindow>
      <MiniPanel xstyle={styles.panel}>
        <MiniBarsRow widths={[100, 44]} />
        <MiniBarsRow widths={[76]} />
        <MiniRow time={tile.time}>
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
    maxWidth: { default: 150, [media.wide]: 'none' },
    whiteSpace: 'normal',
  },
  typing: {
    animationName: { default: null, [media.motion]: typing },
  },
  caret: {
    display: 'inline-block',
    verticalAlign: 'top',
    width: 1,
    height: 13,
    marginTop: 1.5,
    marginLeft: 1,
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
  },
  growing: {
    animationName: { default: null, [media.motion]: grow },
  },
})
