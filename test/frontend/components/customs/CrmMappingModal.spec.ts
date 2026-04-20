import { cleanup, fireEvent, render, waitFor } from '@testing-library/svelte'
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import CrmMappingModal from '@/components/customs/CrmMappingModal.svelte'

type AnimationFrameCallback = Parameters<typeof requestAnimationFrame>[0]

interface ScrollRegionState {
  getScrollLeft: () => number
  setScrollLeft: (value: number) => void
}

const rafQueue = new Map<number, AnimationFrameCallback>()
let nextRafId = 1

function buildProps() {
  return {
    open: true,
    showTestAction: false,
    activeCrmProviders: ['hubspot'],
    onsave: vi.fn(),
    ontestcrm: vi.fn(),
    fields: [
      {
        id: 42,
        label: 'Company name',
        field_type: 'text',
        required: false,
        position: 1,
        metadata: {},
      },
    ],
    crmProperties: {
      hubspot: {
        contact: [
          { name: 'firstname', label: 'First name', type: 'string', read_only: false },
        ],
        company: [
          { name: 'name', label: 'Company name', type: 'string', read_only: false },
        ],
      },
    },
  }
}

function installScrollableRegion(region: HTMLDivElement, initialScrollLeft = 0): ScrollRegionState {
  let scrollLeft = initialScrollLeft

  Object.defineProperty(region, 'clientWidth', {
    configurable: true,
    get: () => 320,
  })

  Object.defineProperty(region, 'scrollWidth', {
    configurable: true,
    get: () => 960,
  })

  Object.defineProperty(region, 'scrollLeft', {
    configurable: true,
    get: () => scrollLeft,
    set: (value: number) => {
      scrollLeft = value
    },
  })

  region.getBoundingClientRect = () => ({
    x: 0,
    y: 0,
    left: 0,
    top: 0,
    right: 320,
    bottom: 240,
    width: 320,
    height: 240,
    toJSON: () => ({}),
  } as DOMRect)

  return {
    getScrollLeft: () => scrollLeft,
    setScrollLeft: (value: number) => {
      scrollLeft = value
    },
  }
}

function flushNextAnimationFrame(time = 16) {
  const next = rafQueue.entries().next().value as [number, AnimationFrameCallback] | undefined

  if (!next) return false

  const [id, callback] = next
  rafQueue.delete(id)
  callback(time)
  return true
}

describe('CrmMappingModal hover scroll affordance', () => {
  beforeEach(() => {
    vi.clearAllMocks()
    rafQueue.clear()
    nextRafId = 1

    vi.stubGlobal('requestAnimationFrame', (callback: AnimationFrameCallback) => {
      const rafId = nextRafId
      nextRafId += 1
      rafQueue.set(rafId, callback)
      return rafId
    })

    vi.stubGlobal('cancelAnimationFrame', (rafId: number) => {
      rafQueue.delete(rafId)
    })
  })

  afterEach(() => {
    cleanup()
    vi.unstubAllGlobals()
    rafQueue.clear()
  })

  it('renders discreet edge controls for horizontal scrolling', () => {
    const { container } = render(CrmMappingModal, { props: buildProps() })
    const region = container.querySelector('[data-scroll-provider="hubspot"]') as HTMLDivElement
    const shell = container.querySelector('[data-testid="crm-mapping-scroll-shell-hubspot"]') as HTMLDivElement
    const rightCue = container.querySelector('[data-testid="crm-mapping-scroll-cue-hubspot-right"]') as HTMLDivElement
    const leftCue = container.querySelector('[data-testid="crm-mapping-scroll-cue-hubspot-left"]') as HTMLDivElement

    expect(region).toBeInTheDocument()
    expect(shell).toBeInTheDocument()
    expect(leftCue).toBeInTheDocument()
    expect(rightCue).toBeInTheDocument()
    expect(leftCue).toHaveClass('w-5', 'bg-white/20', 'opacity-0')
    expect(rightCue).toHaveClass('w-5', 'bg-white/20', 'opacity-0')
  })

  it('scrolls in the hovered edge direction and stops after pointer leave', async () => {
    const { container } = render(CrmMappingModal, { props: buildProps() })
    const region = container.querySelector('[data-scroll-provider="hubspot"]') as HTMLDivElement
    const shell = container.querySelector('[data-testid="crm-mapping-scroll-shell-hubspot"]') as HTMLDivElement
    const rightCue = container.querySelector('[data-testid="crm-mapping-scroll-cue-hubspot-right"]') as HTMLButtonElement
    const leftCue = container.querySelector('[data-testid="crm-mapping-scroll-cue-hubspot-left"]') as HTMLButtonElement
    const scrollState = installScrollableRegion(region)

    await fireEvent.pointerEnter(shell)

    await waitFor(() => {
      expect(rightCue).toHaveClass('opacity-100')
      expect(leftCue).toHaveClass('opacity-100')
    })

    await fireEvent.pointerEnter(rightCue)

    expect(rafQueue.size).toBe(1)

    flushNextAnimationFrame()

    await waitFor(() => {
      expect(scrollState.getScrollLeft()).toBeGreaterThan(0)
      expect(rightCue).toHaveClass('text-gray-800')
    })

    const scrollLeftBeforeLeave = scrollState.getScrollLeft()

    await fireEvent.pointerLeave(shell)

    await waitFor(() => {
      expect(rightCue).toHaveClass('opacity-0')
    })

    expect(rafQueue.size).toBe(0)
    expect(scrollState.getScrollLeft()).toBe(scrollLeftBeforeLeave)

    scrollState.setScrollLeft(scrollLeftBeforeLeave)

    await fireEvent.pointerEnter(leftCue)
    flushNextAnimationFrame()

    await waitFor(() => {
      expect(scrollState.getScrollLeft()).toBeLessThan(scrollLeftBeforeLeave)
      expect(leftCue).toHaveClass('text-gray-800')
    })
  })

  it('keeps keyboard arrow scrolling available for the table region', async () => {
    const { container } = render(CrmMappingModal, { props: buildProps() })
    const region = container.querySelector('[data-scroll-provider="hubspot"]') as HTMLDivElement
    const scrollState = installScrollableRegion(region)

    await fireEvent.keyDown(region, { key: 'ArrowRight' })
    expect(scrollState.getScrollLeft()).toBe(160)

    await fireEvent.keyDown(region, { key: 'ArrowLeft' })
    expect(scrollState.getScrollLeft()).toBe(0)
  })
})