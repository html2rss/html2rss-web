import { afterEach, describe, expect, it } from 'vitest';
import { getPersistentStorage } from '../utils/persistentStorage';

describe('getPersistentStorage', () => {
  afterEach(() => {
    Reflect.deleteProperty(globalThis, 'window');
    Reflect.deleteProperty(globalThis, 'localStorage');
    Reflect.deleteProperty(globalThis, 'sessionStorage');
  });

  it('uses the in-memory store when window is unavailable', () => {
    const storage = getPersistentStorage();
    storage.clear();
    storage.setItem('k', 'v');
    expect(storage.getItem('k')).toBe('v');
    storage.removeItem('k');
    expect(storage.getItem('k')).toBeNull();
  });

  it('falls back to memory when localStorage and sessionStorage throw on access', () => {
    Object.defineProperties(globalThis, {
      window: { value: globalThis, configurable: true },
      localStorage: {
        configurable: true,
        get() {
          throw new Error('blocked');
        },
      },
      sessionStorage: {
        configurable: true,
        get() {
          throw new Error('blocked');
        },
      },
    });

    const storage = getPersistentStorage();
    storage.clear();
    storage.setItem('memory-key', 'memory-value');
    expect(storage.getItem('memory-key')).toBe('memory-value');
  });
});
