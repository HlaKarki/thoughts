import * as stylex from '@stylexjs/stylex'
import { createFileRoute } from '@tanstack/react-router'
import { ButtonLink } from '@/components/ButtonLink'
import { CopyCommand } from '@/components/CopyCommand'
import { RichText } from '@/components/RichText'
import { copper } from '@/content/copper'
import { pageHead } from '@/lib/pageHead'
import { layout } from '@/styles/layout'
import { color, font, leading, media, radius, size, space, tracking, width } from '@/styles/tokens.stylex'
import { Footer } from '../(home)/Footer'
import { Header } from '../(home)/Header'
import { Install } from '../(home)/Install'

export const Route = createFileRoute('/copper-alternative')({
  head: () => pageHead(copper),
  component: CopperAlternative,
})

function CopperAlternative() {
  const [, ...apps] = copper.table.columns
  return (
    <>
      <Header />
      <main>
        <section {...stylex.props(styles.intro)}>
          <h1 {...stylex.props(styles.title)}>{copper.heading}</h1>
          <p {...stylex.props(styles.lead)}>{copper.lead}</p>
          <div {...stylex.props(styles.actions)}>
            <ButtonLink link={copper.download} />
            <CopyCommand command={copper.brew} xstyle={styles.brew} />
          </div>
        </section>

        <section {...stylex.props(layout.column, styles.section)}>
          <h2 {...stylex.props(styles.heading)}>{copper.table.heading}</h2>
          <div {...stylex.props(styles.card)}>
            <table {...stylex.props(styles.table)}>
              <caption {...stylex.props(styles.caption)}>{copper.table.caption}</caption>
              <thead {...stylex.props(styles.head)}>
                <tr>
                  <td />
                  {apps.map((app) => (
                    <th key={app} scope="col" {...stylex.props(styles.columnHeading, app === 'Thoughts' && styles.ours)}>
                      {app}
                    </th>
                  ))}
                </tr>
              </thead>
              <tbody>
                {copper.table.rows.map((row) => (
                  <tr key={row.feature} {...stylex.props(styles.row)}>
                    <th scope="row" {...stylex.props(styles.feature)}>
                      {row.feature}
                    </th>
                    <td data-app={apps[0]} {...stylex.props(styles.cell, styles.ours)}>
                      {row.thoughts}
                    </td>
                    <td data-app={apps[1]} {...stylex.props(styles.cell)}>
                      {row.copper}
                    </td>
                    <td data-app={apps[2]} {...stylex.props(styles.cell)}>
                      {row.cooper}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
          <p {...stylex.props(styles.note)}>{copper.table.checked}</p>
        </section>

        <section {...stylex.props(layout.column, styles.section)}>
          <h2 {...stylex.props(styles.heading)}>{copper.same.heading}</h2>
          <p {...stylex.props(styles.body)}>{copper.same.body}</p>
        </section>

        <section {...stylex.props(layout.column, styles.section)}>
          <div {...stylex.props(styles.picks)}>
            {copper.picks.map((pick) => (
              <article key={pick.heading} {...stylex.props(styles.card, styles.pick)}>
                <h2 {...stylex.props(styles.pickHeading)}>{pick.heading}</h2>
                <ul {...stylex.props(styles.reasons)}>
                  {pick.reasons.map((reason) => (
                    <li key={reason}>{reason}</li>
                  ))}
                </ul>
              </article>
            ))}
          </div>
        </section>

        <section {...stylex.props(layout.column, styles.section)}>
          <h2 {...stylex.props(styles.heading)}>{copper.switching.heading}</h2>
          <ol {...stylex.props(styles.steps)}>
            {copper.switching.steps.map((step, index) => (
              <li key={index} {...stylex.props(styles.step)}>
                <span aria-hidden="true" {...stylex.props(styles.number)}>
                  {index + 1}
                </span>
                <p {...stylex.props(styles.body)}>
                  <RichText text={step} />
                </p>
              </li>
            ))}
          </ol>
        </section>

        <Install />

        <p {...stylex.props(layout.column, styles.affiliation)}>{copper.affiliation}</p>
      </main>
      <Footer />
    </>
  )
}

const styles = stylex.create({
  intro: {
    display: 'flex',
    flexDirection: 'column',
    gap: { default: 14, [media.wide]: 32 },
    width: '100%',
    maxWidth: width.intro,
    marginInline: 'auto',
    paddingInline: space.gutter,
    paddingTop: { default: 40, [media.wide]: 96 },
  },
  title: {
    color: color.text,
    fontFamily: font.display,
    fontSize: { default: size.s32, [media.wide]: size.s40 },
    fontWeight: { default: 600, [media.wide]: 500 },
    lineHeight: { default: '38px', [media.wide]: leading.l48 },
    letterSpacing: { default: tracking.tight, [media.wide]: tracking.display },
    textWrap: 'balance',
  },
  lead: {
    color: { default: color.textMuted, [media.wide]: color.textBody },
    fontFamily: { default: font.text, [media.wide]: font.display },
    fontSize: { default: size.s17, [media.wide]: size.s24 },
    lineHeight: { default: leading.l26, [media.wide]: leading.l36 },
    letterSpacing: { default: tracking.leadNarrow, [media.wide]: tracking.lead },
    textWrap: 'pretty',
  },
  actions: {
    display: { default: 'none', [media.pointer]: 'flex' },
    flexDirection: { default: 'column', [media.wide]: 'row' },
    alignItems: { default: 'stretch', [media.wide]: 'center' },
    gap: 12,
    paddingTop: { default: 8, [media.wide]: 16 },
  },
  brew: {
    flexGrow: { default: 0, [media.wide]: 1 },
    maxWidth: { default: null, [media.wide]: 440 },
  },
  section: {
    display: 'flex',
    flexDirection: 'column',
    gap: { default: 20, [media.wide]: 32 },
    paddingTop: { default: 72, [media.wide]: 120 },
  },
  heading: {
    color: color.text,
    fontFamily: font.display,
    fontSize: { default: size.s24, [media.wide]: size.s32 },
    fontWeight: 500,
    lineHeight: { default: leading.l32, [media.wide]: leading.l40 },
    letterSpacing: tracking.display,
  },
  body: {
    maxWidth: 680,
    color: color.textMuted,
    fontFamily: font.text,
    fontSize: { default: size.s15, [media.wide]: size.s17 },
    lineHeight: { default: leading.l24, [media.wide]: leading.l28 },
  },
  card: {
    borderRadius: { default: radius.r20, [media.wide]: radius.r24 },
    borderWidth: 1,
    borderStyle: 'solid',
    borderColor: color.hairline,
    backgroundColor: color.card,
  },
  table: {
    display: { default: 'block', [media.wide]: 'table' },
    width: '100%',
    borderCollapse: 'collapse',
    fontFamily: font.text,
    fontSize: size.s15,
    lineHeight: leading.l24,
    textAlign: 'start',
  },
  caption: {
    position: 'absolute',
    width: 1,
    height: 1,
    overflow: 'hidden',
    clipPath: 'inset(50%)',
    whiteSpace: 'nowrap',
  },
  head: {
    display: { default: 'none', [media.wide]: 'table-header-group' },
  },
  columnHeading: {
    paddingBlock: 20,
    paddingInline: 24,
    color: color.textMuted,
    fontSize: size.s13,
    fontWeight: 600,
    lineHeight: leading.l16,
    textAlign: 'start',
    borderBottomWidth: 1,
    borderBottomStyle: 'solid',
    borderBottomColor: color.hairline,
  },
  ours: {
    color: color.text,
  },
  row: {
    display: { default: 'flex', [media.wide]: 'table-row' },
    flexDirection: 'column',
    gap: 8,
    padding: { default: 20, [media.wide]: 0 },
    borderBottomWidth: 1,
    borderBottomStyle: 'solid',
    borderBottomColor: { default: color.hairline, ':last-child': 'transparent' },
  },
  feature: {
    width: { default: null, [media.wide]: 180 },
    paddingBlock: { default: 0, [media.wide]: 18 },
    paddingInline: { default: 0, [media.wide]: 24 },
    color: color.text,
    fontWeight: 600,
    textAlign: 'start',
    verticalAlign: 'top',
  },
  cell: {
    display: { default: 'grid', [media.wide]: 'table-cell' },
    gridTemplateColumns: '88px 1fr',
    gap: 12,
    paddingBlock: { default: 0, [media.wide]: 18 },
    paddingInline: { default: 0, [media.wide]: 24 },
    color: color.textMuted,
    verticalAlign: 'top',
    '::before': {
      content: { default: 'attr(data-app)', [media.wide]: 'none' },
      color: color.textMuted,
      fontSize: size.s13,
    },
  },
  note: {
    color: color.textMuted,
    fontFamily: font.text,
    fontSize: size.s13,
    lineHeight: leading.l20,
  },
  picks: {
    display: 'grid',
    gridTemplateColumns: { default: '1fr', [media.wide]: 'repeat(3, 1fr)' },
    gap: 16,
  },
  pick: {
    display: 'flex',
    flexDirection: 'column',
    gap: 16,
    padding: { default: 24, [media.wide]: 32 },
    fontFamily: font.text,
  },
  pickHeading: {
    color: color.text,
    fontSize: size.s17,
    fontWeight: 600,
    lineHeight: leading.l24,
  },
  reasons: {
    display: 'flex',
    flexDirection: 'column',
    gap: 12,
    paddingInlineStart: 18,
    color: color.textMuted,
    fontSize: size.s15,
    lineHeight: leading.l24,
    listStyleType: 'disc',
  },
  steps: {
    display: 'flex',
    flexDirection: 'column',
    gap: 20,
  },
  step: {
    display: 'flex',
    alignItems: 'start',
    gap: 16,
  },
  number: {
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'center',
    flexShrink: 0,
    width: 28,
    height: 28,
    borderRadius: radius.round,
    backgroundColor: color.card,
    color: color.text,
    fontFamily: font.text,
    fontSize: size.s13,
    fontWeight: 600,
  },
  affiliation: {
    paddingTop: 32,
    color: color.textMuted,
    fontFamily: font.text,
    fontSize: size.s13,
    lineHeight: leading.l20,
  },
})
