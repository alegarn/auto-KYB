export type MappingTableScrollDirection = 'left' | 'right';

const HOVER_SCROLL_STEP = 14;
const HORIZONTAL_SCROLL_STEP = 160;

export class MappingTableScrollController {
  hoveredArea = $state(false);
  hoveredCueDirection = $state<MappingTableScrollDirection | null>(null);

  #container: HTMLDivElement | null = null;
  #frameId: number | null = null;

  register = (node: HTMLDivElement) => {
    this.#container = node;

    return {
      destroy: () => {
        if (this.#container === node) {
          this.#container = null;
        }

        this.stop();
      },
    };
  };

  destroy = () => {
    this.stop();
    this.#container = null;
  };

  isCueHovered = (direction: MappingTableScrollDirection) => {
    return this.hoveredCueDirection === direction;
  };

  handleAreaEnter = () => {
    this.hoveredArea = true;
  };

  handleAreaLeave = () => {
    this.hoveredArea = false;
    this.stop();
  };

  handleCueEnter = (direction: MappingTableScrollDirection) => {
    this.hoveredCueDirection = direction;

    if (this.#frameId === null) {
      this.#frameId = requestAnimationFrame(this.#runHoverFrame);
    }
  };

  handleCueLeave = () => {
    this.stop();
  };

  handleKeydown = (event: KeyboardEvent) => {
    if (event.target !== event.currentTarget) return;

    const container = event.currentTarget as HTMLDivElement | null;
    if (!container) return;

    const maxScrollLeft = Math.max(0, container.scrollWidth - container.clientWidth);

    if (event.key === 'ArrowRight') {
      event.preventDefault();
      container.scrollLeft = Math.min(maxScrollLeft, container.scrollLeft + HORIZONTAL_SCROLL_STEP);
    } else if (event.key === 'ArrowLeft') {
      event.preventDefault();
      container.scrollLeft = Math.max(0, container.scrollLeft - HORIZONTAL_SCROLL_STEP);
    }
  };

  stop = () => {
    if (this.#frameId !== null) {
      cancelAnimationFrame(this.#frameId);
      this.#frameId = null;
    }

    this.hoveredCueDirection = null;
  };

  #runHoverFrame = () => {
    if (!this.#container || !this.hoveredCueDirection) {
      this.#frameId = null;
      return;
    }

    const maxScrollLeft = Math.max(0, this.#container.scrollWidth - this.#container.clientWidth);
    const delta = this.hoveredCueDirection === 'left' ? -HOVER_SCROLL_STEP : HOVER_SCROLL_STEP;
    const nextScrollLeft = Math.min(maxScrollLeft, Math.max(0, this.#container.scrollLeft + delta));

    if (nextScrollLeft === this.#container.scrollLeft) {
      this.#frameId = null;
      return;
    }

    this.#container.scrollLeft = nextScrollLeft;
    this.#frameId = requestAnimationFrame(this.#runHoverFrame);
  };
}
