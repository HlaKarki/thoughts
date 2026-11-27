import { pages } from '../content/pages'
import { site } from '../content/site'

const paths = ['/', ...pages.map((page) => `/${page.slug}`)]

export const prerenderPages = paths.map((path) => ({ path }))

export function sitemapXml() {
  const urls = paths.map((path) => `  <url>\n    <loc>${site.url}${path}</loc>\n  </url>`).join('\n')
  return `<?xml version="1.0" encoding="UTF-8"?>\n<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">\n${urls}\n</urlset>\n`
}

export function llmsTxt() {
  const lines = [
    `# ${site.name}`,
    '',
    `> ${site.description}`,
    '',
    `Thoughts is a free, open source Mac app under the MIT License. It needs ${site.operatingSystem}. Install it with \`brew install --cask hlakarki/tap/thoughts\` or download it from ${site.links.download}.`,
    '',
    '## Pages',
    '',
    `- [Home](${site.url}/): ${site.description}`,
    ...pages.map((page) => `- [${page.label}](${site.url}/${page.slug}): ${page.description}`),
    '',
    '## Source',
    '',
    `- [GitHub repository](${site.links.source}): the README documents the file format, every key, the command line tool and the MCP server.`,
    `- [Releases](${site.links.source}/releases): every version with its changelog.`,
    '',
  ]
  return lines.join('\n')
}
