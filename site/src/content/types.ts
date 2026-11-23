export type RichPart = string | { readonly code: string } | { readonly strong: string }

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
