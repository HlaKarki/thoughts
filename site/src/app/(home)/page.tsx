import { createFileRoute } from '@tanstack/react-router'
import { Header } from './Header'
import { Hero } from './Hero'
import { Intro } from './Intro'

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
      </main>
    </>
  )
}
