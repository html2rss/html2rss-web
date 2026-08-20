/** Domain catalog entry used for find and starter selection. */
export interface CatalogEntry {
  id: string;
  path: string;
  title: string;
  description: string;
  channelUrl: string;
  /** String defaults from wire `parameters.defaults` (empty when none). */
  parameterDefaults: Readonly<Record<string, string>>;
}
