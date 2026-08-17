import '@testing-library/jest-dom';
import { afterAll, afterEach, beforeAll, beforeEach, vi } from 'vitest';
import { cleanup } from '@testing-library/preact';

let server: typeof import('./mocks/server').server;

// Mock window and document for tests
Object.defineProperty(globalThis, 'matchMedia', {
  writable: true,
  value: vi.fn().mockImplementation((query) => ({
    matches: false,
    media: query,
    onchange: undefined,
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
      // eslint-disable-next-line unicorn/no-null -- Web Storage returns null for missing keys.
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
      // eslint-disable-next-line unicorn/no-null, unicorn/prefer-iterator-to-array -- Web Storage key() returns null for out-of-range indexes.
      key: vi.fn((index: number) => [...store.keys()][index] ?? null),
    },
  };
};

const local = createStorageMock();
const session = createStorageMock();

Object.defineProperties(globalThis, {
  localStorage: {
    value: local.api,
    configurable: true,
    writable: true,
  },
  sessionStorage: {
    value: session.api,
    configurable: true,
    writable: true,
  },
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

if (typeof HTMLDialogElement !== 'undefined') {
  const dialogPrototype = HTMLDialogElement.prototype;
  if (typeof dialogPrototype.showModal !== 'function') {
    dialogPrototype.showModal = function showModal() {
      this.setAttribute('open', '');
    };
  }
  if (typeof dialogPrototype.close !== 'function') {
    dialogPrototype.close = function close() {
      this.removeAttribute('open');
    };
  }
}

// Wire up MSW in node environment
beforeAll(async () => {
  // eslint-disable-next-line unicorn/no-top-level-assignment-in-function
  ({ server } = await import('./mocks/server'));
  server.listen({ onUnhandledRequest: 'error' });
});
afterEach(() => {
  server.resetHandlers();
  cleanup();
});
afterAll(() => server.close());
