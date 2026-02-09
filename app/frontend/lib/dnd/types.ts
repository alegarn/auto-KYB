export type DragSourceKind = 'palette' | 'canvas';

export interface DragData {
  kind: DragSourceKind;
  fieldType?: string;
  fieldIndex?: number;
  label: string;
  badge: string;
}

export interface DropResult {
  data: DragData;
  index: number;
}

export interface DraggableConfig {
  data: () => DragData;
  handle?: string;
}

export interface DropZoneConfig {
  onDrop: (result: DropResult) => void;
}
