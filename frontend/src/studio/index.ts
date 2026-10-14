/**
 * Narrow studio public facade: editor, capability/mode types, outbound selectors.
 * Internal model/service/hook modules stay importable for tests and adjacent owners.
 */
export { ConfigStudio, type AuthenticatedStudioCapability } from './ConfigStudio';
export type { StudioEditorMode } from './studioModel';
export type { StudioSelectors } from './selectorDraft';
