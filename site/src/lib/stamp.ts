export type Day = {
  readonly year: number
  readonly month: number
  readonly date: number
}

function pad(value: number | string): string {
  return String(value).padStart(2, '0')
}

export function clockDate(day: Day): string {
  const at = new Date(Date.UTC(day.year, day.month - 1, day.date))
  const part = (options: Intl.DateTimeFormatOptions) => at.toLocaleDateString('en-US', { ...options, timeZone: 'UTC' })
  return `${part({ weekday: 'short' })} ${part({ month: 'short' })} ${day.date}`
}

export function stamp(day: Day, time: string, seconds: number) {
  const [hours = '0', minutes = '0'] = time.split(':')
  const date = [day.year, pad(day.month), pad(day.date)]
  const clock = [pad(hours), pad(minutes), pad(seconds)]
  return {
    file: `${date.join('')}-${clock.join('')}`,
    iso: `${date.join('-')}T${clock.join(':')}`,
  }
}
