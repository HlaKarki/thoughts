import type { Rich } from '@/content/types'

export function plainText(text: Rich) {
  return text
    .map((part) =>
      typeof part === 'string' ? part : 'code' in part ? part.code : 'link' in part ? part.link.label : part.strong,
    )
    .join('')
}
