import { createFileRoute } from '@tanstack/react-router'
import { Features } from './Features'
import { Header } from './Header'
import { Hero } from './Hero'
import { Intro } from './Intro'
import { Keyboard } from './Keyboard'

export const Route = createFileRoute('/')({
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
      </main>
    </>
  )
}
