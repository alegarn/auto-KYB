type AutosaveOptions = {
  onSave: () => Promise<void>
  delayMs: number
  minIntervalMs: number
}

export type AutosaveController = {
  schedule: () => void
  cancel: () => void
  flush: () => Promise<void>
}

function isSameValue(a: any, b: any) {
  if (a === b) return true
  if (typeof a === 'object' || typeof b === 'object') {
    return JSON.stringify(a) === JSON.stringify(b)
  }
  return false
}

export function buildDelta(
  formState: Record<string, any>,
  baseState: Record<string, any>
) {
  const delta: Record<string, any> = {}
  for (const [id, value] of Object.entries(formState)) {
    if (!isSameValue(value, baseState[id])) {
      delta[id] = value
    }
  }
  return delta
}

export function mergeBase(
  baseState: Record<string, any>,
  patch: Record<string, any>
) {
  return { ...baseState, ...patch }
}

export function createAutosave(options: AutosaveOptions): AutosaveController {
  let timeoutId: ReturnType<typeof setTimeout> | null = null
  let inFlight = false
  let pending = false
  let lastSavedAt = 0
  let currentSave: Promise<void> | null = null

  const schedule = () => {
    pending = true
    if (timeoutId) return
    timeoutId = setTimeout(() => {
      timeoutId = null
      runSave()
    }, options.delayMs)
  }

  const cancel = () => {
    pending = false
    if (timeoutId) {
      clearTimeout(timeoutId)
      timeoutId = null
    }
  }

  const runSave = () => {
    if (inFlight) return

    if (!pending) return
    const now = Date.now()
    const wait = Math.max(0, options.minIntervalMs - (now - lastSavedAt))
    if (wait > 0) {
      timeoutId = setTimeout(() => {
        timeoutId = null
        runSave()
      }, wait)
      return
    }

    pending = false
    inFlight = true
    currentSave = options
      .onSave()
      .finally(() => {
        lastSavedAt = Date.now()
        inFlight = false
        currentSave = null
        if (pending) schedule()
      })
  }

  const flush = async () => {
    if (timeoutId) {
      clearTimeout(timeoutId)
      timeoutId = null
    }
    if (inFlight && currentSave) return currentSave
    pending = true
    runSave()
    if (currentSave) return currentSave
  }

  return { schedule, cancel, flush }
}
