import * as stylex from '@stylexjs/stylex'
import { createFileRoute } from '@tanstack/react-router'
import { color } from '@/styles/tokens.stylex'

export const Route = createFileRoute('/')({
  component: Home,
})

function Home() {
  return <main {...stylex.props(styles.main)}>Thoughts</main>
}

const styles = stylex.create({
  main: { color: color.text },
})
