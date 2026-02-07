import type { DragData, DropZoneConfig } from './types';

const THRESHOLD = 5;

let dragData: DragData | null = null;
let previewEl: HTMLElement | null = null;
let indicatorEl: HTMLElement | null = null;
let originX = 0;
let originY = 0;
let started = false;
let zoneEl: HTMLElement | null = null;
let zoneCfg: DropZoneConfig | null = null;
let targetIdx = -1;
let stylesReady = false;

function injectStyles() {
  if (stylesReady) return;
  stylesReady = true;
  const s = document.createElement('style');
  s.id = 'dnd-styles';
  s.textContent = [
    '.dnd-preview{position:fixed;z-index:10000;pointer-events:none;display:flex;align-items:center;gap:8px;padding:8px 14px;border-radius:10px;background:hsl(var(--card));border:1.5px solid hsl(var(--primary)/0.3);box-shadow:0 12px 32px rgba(0,0,0,.12),0 2px 6px rgba(0,0,0,.08);font-size:13px;font-weight:500;color:hsl(var(--foreground));max-width:220px;white-space:nowrap;overflow:hidden}',
    '.dnd-preview-label{overflow:hidden;text-overflow:ellipsis}',
    '.dnd-preview-badge{flex-shrink:0;font-size:10px;text-transform:uppercase;font-weight:600;letter-spacing:.02em;padding:2px 7px;border-radius:9999px;background:hsl(var(--muted));color:hsl(var(--muted-foreground))}',
    '.dnd-indicator{position:absolute;left:8px;right:8px;height:2px;background:hsl(var(--primary));border-radius:1px;pointer-events:none;z-index:50;transition:top 80ms ease-out}',
    '.dnd-indicator::before,.dnd-indicator::after{content:"";position:absolute;top:-3px;width:8px;height:8px;border-radius:50%;background:hsl(var(--primary))}',
    '.dnd-indicator::before{left:-3px}',
    '.dnd-indicator::after{right:-3px}',
    'body.dnd-active{user-select:none}',
    'body.dnd-active *{cursor:grabbing!important}',
    '[data-drag-handle]{touch-action:none}',
  ].join('\n');
  document.head.appendChild(s);
}

function esc(t: string): string {
  const d = document.createElement('span');
  d.textContent = t;
  return d.innerHTML;
}

function makePreview(data: DragData, x: number, y: number): HTMLElement {
  injectStyles();
  const el = document.createElement('div');
  el.className = 'dnd-preview';
  el.innerHTML =
    `<span class="dnd-preview-label">${esc(data.label)}</span>` +
    `<span class="dnd-preview-badge">${esc(data.badge)}</span>`;
  el.style.left = `${x + 12}px`;
  el.style.top = `${y - 14}px`;
  document.body.appendChild(el);
  return el;
}

function makeIndicator(): HTMLElement {
  const el = document.createElement('div');
  el.className = 'dnd-indicator';
  el.style.display = 'none';
  return el;
}

function getItemsContainer(): HTMLElement | null {
  if (!zoneEl) return null;
  return (zoneEl.querySelector('[data-dnd-items]') as HTMLElement) || zoneEl;
}

function getItems(): HTMLElement[] {
  const c = getItemsContainer();
  if (!c) return [];
  return Array.from(c.querySelectorAll(':scope > [data-dnd-item]'));
}

function isOverZone(x: number, y: number): boolean {
  if (!zoneEl) return false;
  const r = zoneEl.getBoundingClientRect();
  return x >= r.left && x <= r.right && y >= r.top && y <= r.bottom;
}

function computeIndex(clientY: number): number {
  const items = getItems();
  if (items.length === 0) return 0;
  for (let i = 0; i < items.length; i++) {
    const r = items[i].getBoundingClientRect();
    if (clientY < r.top + r.height / 2) return i;
  }
  return items.length;
}

function showIndicator(idx: number) {
  const c = getItemsContainer();
  if (!c || !indicatorEl) return;
  if (indicatorEl.parentElement !== c) {
    c.style.position = 'relative';
    c.appendChild(indicatorEl);
  }
  indicatorEl.style.display = '';
  const items = getItems();
  let y: number;
  if (items.length === 0) {
    y = c.clientHeight / 2;
  } else if (idx <= 0) {
    y = items[0].offsetTop - 1;
  } else if (idx >= items.length) {
    const last = items[items.length - 1];
    y = last.offsetTop + last.offsetHeight + 1;
  } else {
    const prev = items[idx - 1];
    const next = items[idx];
    y = Math.round((prev.offsetTop + prev.offsetHeight + next.offsetTop) / 2);
  }
  indicatorEl.style.top = `${y}px`;
}

function hideIndicator() {
  if (indicatorEl) indicatorEl.style.display = 'none';
}

function onMove(e: PointerEvent) {
  if (!dragData) return;
  const dx = e.clientX - originX;
  const dy = e.clientY - originY;
  if (!started) {
    if (dx * dx + dy * dy < THRESHOLD * THRESHOLD) return;
    started = true;
    previewEl = makePreview(dragData, e.clientX, e.clientY);
    indicatorEl = makeIndicator();
    document.body.classList.add('dnd-active');
  }
  if (previewEl) {
    previewEl.style.left = `${e.clientX + 12}px`;
    previewEl.style.top = `${e.clientY - 14}px`;
  }
  if (isOverZone(e.clientX, e.clientY)) {
    targetIdx = computeIndex(e.clientY);
    showIndicator(targetIdx);
  } else {
    targetIdx = -1;
    hideIndicator();
  }
}

function onUp() {
  if (started && dragData && targetIdx >= 0) {
    zoneCfg?.onDrop({ data: { ...dragData }, index: targetIdx });
  }
  finish(started);
}

function onKey(e: KeyboardEvent) {
  if (e.key === 'Escape') finish(started);
}

function blockClick(e: Event) {
  e.stopPropagation();
  e.preventDefault();
}

function finish(wasDrag: boolean) {
  previewEl?.remove();
  indicatorEl?.remove();
  document.removeEventListener('pointermove', onMove);
  document.removeEventListener('pointerup', onUp);
  document.removeEventListener('keydown', onKey);
  document.body.classList.remove('dnd-active');
  dragData = null;
  previewEl = null;
  indicatorEl = null;
  started = false;
  targetIdx = -1;
  if (wasDrag) {
    document.addEventListener('click', blockClick, { capture: true, once: true });
  }
}

export function beginDrag(data: DragData, origin: { x: number; y: number }) {
  if (started) finish(true);
  dragData = data;
  originX = origin.x;
  originY = origin.y;
  started = false;
  document.addEventListener('pointermove', onMove);
  document.addEventListener('pointerup', onUp);
  document.addEventListener('keydown', onKey);
}

export function registerDropZone(el: HTMLElement, cfg: DropZoneConfig): () => void {
  zoneEl = el;
  zoneCfg = cfg;
  return () => {
    if (zoneEl === el) {
      zoneEl = null;
      zoneCfg = null;
    }
  };
}
