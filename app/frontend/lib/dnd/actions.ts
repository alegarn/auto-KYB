import type { DraggableConfig, DropZoneConfig } from './types';
import { beginDrag, registerDropZone } from './engine';

export function draggable(node: HTMLElement, config: DraggableConfig) {
  let cfg = config;

  function onPointerDown(e: PointerEvent) {
    if (e.button !== 0) return;
    if (cfg.handle) {
      const h = (e.target as HTMLElement).closest(cfg.handle);
      if (!h || !node.contains(h)) return;
    }
    beginDrag(cfg.data(), { x: e.clientX, y: e.clientY });
  }

  node.addEventListener('pointerdown', onPointerDown);

  return {
    update(next: DraggableConfig) {
      cfg = next;
    },
    destroy() {
      node.removeEventListener('pointerdown', onPointerDown);
    },
  };
}

export function dropZone(node: HTMLElement, config: DropZoneConfig) {
  let cleanup = registerDropZone(node, config);

  return {
    update(next: DropZoneConfig) {
      cleanup();
      cleanup = registerDropZone(node, next);
    },
    destroy() {
      cleanup();
    },
  };
}
