import { readFile } from 'node:fs/promises'
import { site } from '../src/content/site'

const sitemap = await readFile(new URL('../dist/client/sitemap.xml', import.meta.url), 'utf8')
const urlList = [...sitemap.matchAll(/<loc>([^<]+)<\/loc>/g)].map((match) => match[1])

const response = await fetch('https://api.indexnow.org/indexnow', {
  method: 'POST',
  headers: { 'Content-Type': 'application/json; charset=utf-8' },
  body: JSON.stringify({
    host: new URL(site.url).host,
    key: site.indexNowKey,
    keyLocation: `${site.url}/${site.indexNowKey}.txt`,
    urlList,
  }),
})

if (!response.ok) {
  console.error(`IndexNow answered ${response.status}: ${await response.text()}`)
  process.exit(1)
}
console.log(`IndexNow took ${urlList.length} pages (${response.status})`)
