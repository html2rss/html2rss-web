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

// Persistent localStorage stub with in-memory backing store
const localStorageStore = new Map<string, string>();
const localStorageMock = {
  getItem: vi.fn((key: string) => (localStorageStore.has(key) ? localStorageStore.get(key)! : null)),
  setItem: vi.fn((key: string, value: string) => {
    localStorageStore.set(key, value);
  }),
  removeItem: vi.fn((key: string) => {
    localStorageStore.delete(key);
  }),
  clear: vi.fn(() => {
    localStorageStore.clear();
  }),
};

Object.defineProperty(window, 'localStorage', {
  value: localStorageMock,
});

beforeEach(() => {
  localStorageStore.clear();
  localStorageMock.getItem.mockClear();
  localStorageMock.setItem.mockClear();
  localStorageMock.removeItem.mockClear();
  localStorageMock.clear.mockClear();
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
