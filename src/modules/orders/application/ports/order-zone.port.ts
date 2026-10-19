export interface OrderZonePort {
  // Existing Zones has no lifecycle yet. A real lookup must supply active when supported.
  findById(id: string): Promise<{ readonly id: string; readonly active?: boolean } | null>;
}
