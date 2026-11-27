export type RichPart =
  | string
  | { readonly code: string }
  | { readonly strong: string }
  | { readonly link: Link }

export type Rich = ReadonlyArray<RichPart>

export type Link = {
  readonly label: string
  readonly href: string
}

export type Image = {
  readonly src: string
  readonly alt: string
}

export type ThemedImage = {
  readonly light: string
  readonly dark: string
  readonly alt: string
}

export type Comparison = {
  readonly feature: string
  readonly cells: ReadonlyArray<string>
}

export type PickCard = {
  readonly heading: string
  readonly reasons: ReadonlyArray<string>
}

export type Question = {
  readonly question: string
  readonly answer: Rich
}

export type Block =
  | { readonly kind: 'text'; readonly text: Rich }
  | { readonly kind: 'list'; readonly items: ReadonlyArray<Rich> }
  | { readonly kind: 'steps'; readonly items: ReadonlyArray<Rich> }
  | { readonly kind: 'code'; readonly label: string; readonly code: string }
  | {
      readonly kind: 'compare'
      readonly caption: string
      readonly columns: ReadonlyArray<string>
      readonly rows: ReadonlyArray<Comparison>
      readonly note: string
    }
  | { readonly kind: 'picks'; readonly picks: ReadonlyArray<PickCard> }
  | { readonly kind: 'questions'; readonly items: ReadonlyArray<Question> }

export type Section = {
  readonly heading?: string
  readonly blocks: ReadonlyArray<Block>
}

export type Page = {
  readonly slug: string
  readonly label: string
  readonly title: string
  readonly description: string
  readonly heading: string
  readonly lead: string
  readonly sections: ReadonlyArray<Section>
  readonly footnote?: string
}
