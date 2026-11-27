import { createFileRoute } from '@tanstack/react-router'
import { site } from '@/content/site'
import { pageHead } from '@/lib/pageHead'
import { Features } from './Features'
import { Footer } from './Footer'
import { Header } from './Header'
import { Hero } from './Hero'
import { Install } from './Install'
import { Intro } from './Intro'
import { Keyboard } from './Keyboard'

export const Route = createFileRoute('/')({
  head: () => pageHead({ path: '/', title: site.title, description: site.description }),
  component: Home,
})

function Home() {
  return (
    <>
      <Header />
      <main>
        <Intro />
        <Hero />
        <Features />
        <Keyboard />
        <Install />
      </main>
      <Footer />
    </>
  )
}
