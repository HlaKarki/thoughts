import type { Link } from './types'

type NotFound = {
  readonly heading: string
  readonly body: string
  readonly home: Link
}

export const notFound: NotFound = {
  heading: 'There is no page at this address.',
  body: 'The link may be old or mistyped. You can find everything about Thoughts on the home page.',
  home: { label: 'Go to the home page', href: '/' },
}
