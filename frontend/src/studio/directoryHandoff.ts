/** GitHub new-issue handoff for Riley — not in-app directory authoring. */

const DIRECTORY_ISSUE_NEW = 'https://github.com/html2rss/html2rss-configs/issues/new';

/**
 * Build a prefilled html2rss-configs issue URL.
 * Body is channel.url + studio selectors YAML plus blank directory fields.
 * Never includes access or feed tokens.
 */
export function buildDirectoryIssueHref(channelUrl: string, selectorsYaml: string): string {
  const title = `Add feed: ${channelUrl}`;
  const body = buildDirectoryIssueBody(channelUrl, selectorsYaml);
  const parameters = new URLSearchParams({ title, body });
  return `${DIRECTORY_ISSUE_NEW}?${parameters.toString()}`;
}

/** YAML stub for the issue body — blank directory.title / directory.topics for Riley. */
export function buildDirectoryIssueBody(channelUrl: string, selectorsYaml: string): string {
  const base = selectorsYaml.trim() || `channel:\n  url: ${channelUrl}\nselectors: {}\n`;
  return `${base.trimEnd()}\n\ndirectory:\n  title:\n  topics:\n`;
}
