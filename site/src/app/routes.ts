import { index, rootRoute, route } from '@tanstack/virtual-file-routes'

export const routes = rootRoute('__root.tsx', [index('(home)/page.tsx'), route('/$page', '(pages)/page.tsx')])
