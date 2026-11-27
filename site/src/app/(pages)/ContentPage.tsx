import * as stylex from '@stylexjs/stylex'
import { ButtonLink } from '@/components/ButtonLink'
import { CopyCommand } from '@/components/CopyCommand'
import { RichText } from '@/components/RichText'
import { intro } from '@/content/intro'
import type { Block, Page } from '@/content/types'
import { layout } from '@/styles/layout'
import { color, font, leading, media, radius, size, space, tracking, width } from '@/styles/tokens.stylex'
import { Footer } from '../(home)/Footer'
import { Header } from '../(home)/Header'
import { Install } from '../(home)/Install'

type Props = {
  readonly page: Page
  readonly related: ReadonlyArray<Page>
}

export function ContentPage({ page, related }: Props) {
  return (
    <>
      <Header />
      <main>
        <section {...stylex.props(styles.intro)}>
          <h1 {...stylex.props(styles.title)}>{page.heading}</h1>
          <p {...stylex.props(styles.lead)}>{page.lead}</p>
          <div {...stylex.props(styles.actions)}>
            <ButtonLink link={intro.download} />
            <CopyCommand command={intro.brew} xstyle={styles.brew} />
          </div>
        </section>

        {page.sections.map((section, index) => (
          <section key={section.heading ?? index} {...stylex.props(layout.column, styles.section)}>
            {section.heading && <h2 {...stylex.props(styles.heading)}>{section.heading}</h2>}
            {section.blocks.map((block, blockIndex) => (
              <BlockView key={blockIndex} block={block} />
            ))}
          </section>
        ))}

        <Install />

        {page.footnote && <p {...stylex.props(layout.column, styles.footnote)}>{page.footnote}</p>}

        <nav aria-labelledby="related" {...stylex.props(layout.column, styles.section)}>
          <h2 id="related" {...stylex.props(styles.heading)}>
            More about Thoughts
          </h2>
          <ul {...stylex.props(styles.related)}>
            {related.map((other) => (
              <li key={other.slug}>
                <a href={`/${other.slug}`} {...stylex.props(styles.card, styles.relatedLink)}>
                  <span {...stylex.props(styles.relatedLabel)}>{other.label}</span>
                  <span {...stylex.props(styles.relatedBody)}>{other.description}</span>
                </a>
              </li>
            ))}
          </ul>
        </nav>
      </main>
      <Footer />
    </>
  )
}

function BlockView({ block }: { readonly block: Block }) {
  switch (block.kind) {
    case 'text':
      return (
        <p {...stylex.props(styles.body)}>
          <RichText text={block.text} codeXstyle={styles.inlineCode} />
        </p>
      )
    case 'list':
      return (
        <ul {...stylex.props(styles.body, styles.bullets)}>
          {block.items.map((item, index) => (
            <li key={index}>
              <RichText text={item} codeXstyle={styles.inlineCode} />
            </li>
          ))}
        </ul>
      )
    case 'steps':
      return (
        <ol {...stylex.props(styles.steps)}>
          {block.items.map((item, index) => (
            <li key={index} {...stylex.props(styles.step)}>
              <span aria-hidden="true" {...stylex.props(styles.number)}>
                {index + 1}
              </span>
              <p {...stylex.props(styles.body)}>
                <RichText text={item} codeXstyle={styles.inlineCode} />
              </p>
            </li>
          ))}
        </ol>
      )
    case 'code':
      return (
        <figure {...stylex.props(styles.codeCard)}>
          <figcaption {...stylex.props(styles.codeLabel)}>{block.label}</figcaption>
          <pre {...stylex.props(styles.pre)}>
            <code>{block.code}</code>
          </pre>
        </figure>
      )
    case 'compare':
      return <CompareTable block={block} />
    case 'picks':
      return (
        <div {...stylex.props(styles.picks, block.picks.length === 2 && styles.twoPicks)}>
          {block.picks.map((pick) => (
            <article key={pick.heading} {...stylex.props(styles.card, styles.pick)}>
              <h3 {...stylex.props(styles.pickHeading)}>{pick.heading}</h3>
              <ul {...stylex.props(styles.reasons)}>
                {pick.reasons.map((reason) => (
                  <li key={reason}>{reason}</li>
                ))}
              </ul>
            </article>
          ))}
        </div>
      )
    case 'questions':
      return (
        <dl {...stylex.props(styles.questions)}>
          {block.items.map((item) => (
            <div key={item.question} {...stylex.props(styles.question)}>
              <dt {...stylex.props(styles.questionText)}>{item.question}</dt>
              <dd {...stylex.props(styles.body, styles.answer)}>
                <RichText text={item.answer} codeXstyle={styles.inlineCode} />
              </dd>
            </div>
          ))}
        </dl>
      )
  }
}

function CompareTable({ block }: { readonly block: Extract<Block, { kind: 'compare' }> }) {
  return (
    <>
      <div {...stylex.props(styles.card)}>
        <table {...stylex.props(styles.table)}>
          <caption {...stylex.props(styles.caption)}>{block.caption}</caption>
          <thead {...stylex.props(styles.head)}>
            <tr>
              <td />
              {block.columns.map((column, index) => (
                <th key={column} scope="col" {...stylex.props(styles.columnHeading, index === 0 && styles.ours)}>
                  {column}
                </th>
              ))}
            </tr>
          </thead>
          <tbody>
            {block.rows.map((row) => (
              <tr key={row.feature} {...stylex.props(styles.row)}>
                <th scope="row" {...stylex.props(styles.feature)}>
                  {row.feature}
                </th>
                {row.cells.map((cell, index) => (
                  <td key={index} data-app={block.columns[index]} {...stylex.props(styles.cell, index === 0 && styles.ours)}>
                    {cell}
                  </td>
                ))}
              </tr>
            ))}
          </tbody>
        </table>
      </div>
      <p {...stylex.props(styles.note)}>{block.note}</p>
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
    gap: { default: 20, [media.wide]: 28 },
    paddingTop: { default: 72, [media.wide]: 112 },
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
  inlineCode: {
    fontSize: { default: size.s13, [media.wide]: size.s15 },
  },
  bullets: {
    display: 'flex',
    flexDirection: 'column',
    gap: 10,
    paddingInlineStart: 20,
    listStyleType: 'disc',
  },
  card: {
    borderRadius: { default: radius.r20, [media.wide]: radius.r24 },
    borderWidth: 1,
    borderStyle: 'solid',
    borderColor: color.hairline,
    backgroundColor: color.card,
  },
  codeCard: {
    maxWidth: 760,
    margin: 0,
    overflow: 'clip',
    borderRadius: radius.r12,
    borderWidth: 1,
    borderStyle: 'solid',
    borderColor: color.hairline,
    backgroundColor: color.inset,
  },
  codeLabel: {
    display: 'flex',
    alignItems: 'center',
    height: 40,
    paddingInline: { default: 16, [media.wide]: 20 },
    borderBottomWidth: 1,
    borderBottomStyle: 'solid',
    borderBottomColor: color.hairline,
    backgroundColor: color.card,
    color: color.textMuted,
    fontFamily: font.text,
    fontSize: size.s13,
    lineHeight: leading.l16,
  },
  pre: {
    margin: 0,
    padding: { default: 16, [media.wide]: 20 },
    overflowX: 'auto',
    color: color.textBody,
    fontFamily: font.mono,
    fontSize: { default: size.s12, [media.wide]: size.s14 },
    lineHeight: leading.l20,
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
  twoPicks: {
    gridTemplateColumns: { default: '1fr', [media.wide]: 'repeat(2, 1fr)' },
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
  questions: {
    display: 'flex',
    flexDirection: 'column',
    margin: 0,
  },
  question: {
    display: 'flex',
    flexDirection: 'column',
    gap: 8,
    paddingBlock: { default: 20, [media.wide]: 24 },
    borderBottomWidth: 1,
    borderBottomStyle: 'solid',
    borderBottomColor: color.hairline,
  },
  questionText: {
    color: color.text,
    fontFamily: font.text,
    fontSize: size.s17,
    fontWeight: 600,
    lineHeight: leading.l24,
  },
  answer: {
    margin: 0,
  },
  footnote: {
    paddingTop: 32,
    color: color.textMuted,
    fontFamily: font.text,
    fontSize: size.s13,
    lineHeight: leading.l20,
  },
  related: {
    display: 'grid',
    gridTemplateColumns: { default: '1fr', [media.wide]: 'repeat(3, 1fr)' },
    gap: 16,
  },
  relatedLink: {
    display: 'flex',
    flexDirection: 'column',
    gap: 8,
    height: '100%',
    padding: { default: 20, [media.wide]: 24 },
    fontFamily: font.text,
    borderColor: { default: color.hairline, ':hover': color.textMuted },
  },
  relatedLabel: {
    color: color.text,
    fontSize: size.s15,
    fontWeight: 600,
    lineHeight: leading.l20,
  },
  relatedBody: {
    color: color.textMuted,
    fontSize: size.s13,
    lineHeight: leading.l20,
  },
})
