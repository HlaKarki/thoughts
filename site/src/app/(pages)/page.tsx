import { createFileRoute, notFound } from '@tanstack/react-router'
import { findPage, pages } from '@/content/pages'
import type { Block, Page } from '@/content/types'
import { pageHead } from '@/lib/pageHead'
import { plainText } from '@/lib/plainText'
import { ContentPage } from './ContentPage'

export const Route = createFileRoute('/$page')({
  beforeLoad: ({ params }) => {
    if (!findPage(params.page)) throw notFound()
  },
  head: ({ params }) => {
    const page = findPage(params.page)
    if (!page) return {}
    const head = pageHead({ path: `/${page.slug}`, title: page.title, description: page.description })
    const faq = questionsData(page)
    return faq ? { ...head, scripts: [{ type: 'application/ld+json', children: JSON.stringify(faq) }] } : head
  },
  component: PageRoute,
})

function PageRoute() {
  const { page: slug } = Route.useParams()
  const page = findPage(slug)
  if (!page) return null
  return <ContentPage page={page} related={pages.filter((other) => other.slug !== page.slug)} />
}

function questionsData(page: Page) {
  const questions = page.sections
    .flatMap((section) => section.blocks)
    .filter((block): block is Extract<Block, { kind: 'questions' }> => block.kind === 'questions')
    .flatMap((block) => block.items)
  if (questions.length === 0) return null
  return {
    '@context': 'https://schema.org',
    '@type': 'FAQPage',
    mainEntity: questions.map((item) => ({
      '@type': 'Question',
      name: item.question,
      acceptedAnswer: { '@type': 'Answer', text: plainText(item.answer) },
    })),
  }
}
