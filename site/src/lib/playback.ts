import { useEffect, useState, type RefObject } from 'react'

const startGap = 1000
const visibleToStart = 0.5
const waiting: Array<() => void> = []
let lastStart = Number.NEGATIVE_INFINITY
let timer: number | undefined

function startNext() {
  timer = undefined
  if (!waiting.length) return
  const wait = lastStart + startGap - performance.now()
  if (wait > 0) {
    timer = window.setTimeout(startNext, wait)
    return
  }
  lastStart = performance.now()
  waiting.shift()?.()
  if (waiting.length) timer = window.setTimeout(startNext, startGap)
}

function queueStart(start: () => void): () => void {
  waiting.push(start)
  if (timer === undefined) startNext()
  return () => {
    const index = waiting.indexOf(start)
    if (index >= 0) waiting.splice(index, 1)
  }
}

export function useLoopPlayback(ref: RefObject<HTMLElement | null>): boolean {
  const [playing, setPlaying] = useState(false)
  useEffect(() => {
    const element = ref.current
    if (!element) return
    let started = false
    let leaveQueue: (() => void) | null = null
    const observer = new IntersectionObserver(
      ([entry]) => {
        if (!entry) return
        const halfVisible = entry.intersectionRatio >= visibleToStart
        if (started) {
          if (halfVisible) setPlaying(true)
          else if (!entry.isIntersecting) setPlaying(false)
          return
        }
        if (halfVisible && !leaveQueue) {
          leaveQueue = queueStart(() => {
            leaveQueue = null
            started = true
            setPlaying(true)
          })
        } else if (!halfVisible && leaveQueue) {
          leaveQueue()
          leaveQueue = null
        }
      },
      { threshold: [0, visibleToStart] },
    )
    observer.observe(element)
    return () => {
      observer.disconnect()
      leaveQueue?.()
    }
  }, [ref])
  return playing
}
