import '@testing-library/jest-dom';
import { afterAll, afterEach, beforeAll, beforeEach, vi } from 'vitest';
import { cleanup } from '@testing-library/preact';
import { server } from './mocks/server';

// Mock window and document for tests
Object.defineProperty(window, 'matchMedia', {
  writable: true,
  value: vi.fn().mockImplementation((query) => ({
    matches: false,
    media: query,
    onchange: null,
    addListener: vi.fn(), // deprecated
    removeListener: vi.fn(), // deprecated
    addEventListener: vi.fn(),
    removeEventListener: vi.fn(),
    dispatchEvent: vi.fn(),
  })),
});

// Persistent storage stubs with in-memory backing store
const createStorageMock = () => {
  const store = new Map<string, string>();

  return {
    store,
    api: {
      get length() {
        return store.size;
      },
      getItem: vi.fn((key: string) => (store.has(key) ? store.get(key)! : null)),
      setItem: vi.fn((key: string, value: string) => {
        store.set(key, value);
      }),
      removeItem: vi.fn((key: string) => {
        store.delete(key);
      }),
      clear: vi.fn(() => {
        store.clear();
      }),
      key: vi.fn((index: number) => Array.from(store.keys())[index] ?? null),
    },
  };
};

const local = createStorageMock();
const session = createStorageMock();

Object.defineProperty(window, 'localStorage', {
  value: local.api,
});

Object.defineProperty(window, 'sessionStorage', {
  value: session.api,
});

beforeEach(() => {
  local.store.clear();
  session.store.clear();
  local.api.getItem.mockClear();
  local.api.setItem.mockClear();
  local.api.removeItem.mockClear();
  local.api.clear.mockClear();
  local.api.key.mockClear();
  session.api.getItem.mockClear();
  session.api.setItem.mockClear();
  session.api.removeItem.mockClear();
  session.api.clear.mockClear();
  session.api.key.mockClear();
});

// Mock clipboard API
Object.assign(navigator, {
  clipboard: {
    writeText: vi.fn(() => Promise.resolve()),
  },
});

// Ensure scrollIntoView exists for components relying on it
Element.prototype.scrollIntoView = vi.fn();

// Wire up MSW in node environment
beforeAll(() => server.listen({ onUnhandledRequest: 'error' }));
afterEach(() => {
  server.resetHandlers();
  cleanup();
});
afterAll(() => server.close());
