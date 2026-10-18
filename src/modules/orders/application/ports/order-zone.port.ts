export interface OrderZonePort {
  findById(id: string): Promise<{ readonly id: string; readonly name: string } | null>;
}
