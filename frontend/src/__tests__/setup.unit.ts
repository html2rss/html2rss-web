/** Minimal DOM location for Node unit tests that exercise same-origin HTTP adapters. */
Object.defineProperty(globalThis, 'location', {
  value: { origin: 'http://localhost:3000' },
  configurable: true,
});
