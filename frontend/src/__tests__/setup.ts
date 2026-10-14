import '@testing-library/jest-dom/vitest';
import { afterAll, afterEach, beforeAll, vi } from 'vitest';
import { cleanup } from '@testing-library/preact';
import { server } from './mocks/server';

Object.defineProperty(globalThis, 'matchMedia', {
  writable: true,
  value: (query: string) => ({
    matches: false,
    media: query,
    onchange: undefined,
    addListener: () => {},
    removeListener: () => {},
    addEventListener: () => {},
    removeEventListener: () => {},
    dispatchEvent: () => false,
  }),
});

const clipboardWriteText = vi.fn(() => Promise.resolve());
Object.defineProperty(navigator, 'clipboard', {
  configurable: true,
  value: { writeText: clipboardWriteText },
});

Element.prototype.scrollIntoView = vi.fn();

beforeAll(() => {
  server.listen({ onUnhandledRequest: 'error' });
});

afterEach(() => {
  server.resetHandlers();
  cleanup();
  clipboardWriteText.mockClear();
});

afterAll(() => {
  server.close();
});
