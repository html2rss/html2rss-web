const memoryStorage = (() => {
  const store = new Map<string, string>();

  return {
    get length() {
      return store.size;
    },
    clear: () => store.clear(),
    // Storage#getItem returns null when a key is missing.
    // eslint-disable-next-line unicorn/no-null
    getItem: (key: string) => store.get(key) ?? null,
    // Storage#key returns null when the index is out of range.
    // eslint-disable-next-line unicorn/no-null
    key: (index: number) => [...store.keys()][index] ?? null,
    removeItem: (key: string) => {
      store.delete(key);
    },
    setItem: (key: string, value: string) => {
      store.set(key, value);
    },
  } as Storage;
})();

export function getPersistentStorage(): Storage {
  if (globalThis.window === undefined) return memoryStorage;

  try {
    return globalThis.localStorage ?? globalThis.sessionStorage ?? memoryStorage;
  } catch {
    try {
      return globalThis.sessionStorage ?? memoryStorage;
    } catch {
      return memoryStorage;
    }
  }
}
