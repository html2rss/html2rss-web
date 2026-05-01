import { useCallback, useEffect, useState } from 'preact/hooks';

export type AppRoute =
  | {
      kind: 'create';
      prefillUrl?: string;
    }
  | {
      kind: 'token';
      prefillUrl?: string;
    }
  | {
      kind: 'result';
      feedToken: string;
      prefillUrl?: string;
    };

interface RouteNavigationOptions {
  replace?: boolean;
}

interface RouteLocationLike {
  pathname: string;
  search: string;
  hash: string;
}

const ROUTE_PATHS = {
  create: '/create',
  token: '/token',
  resultPrefix: '/result/',
} as const;

export function readAppRoute(locationLike: RouteLocationLike = getCurrentLocation()): AppRoute {
  const hashRoute = parseHashRoute(locationLike.hash);
  const pathname = normalizePathname(hashRoute.pathname);
  const prefillUrl = new URLSearchParams(hashRoute.search || locationLike.search).get('url') ?? undefined;

  if (pathname === ROUTE_PATHS.create || pathname === '/') {
    return prefillUrl ? { kind: 'create', prefillUrl } : { kind: 'create' };
  }

  if (pathname === ROUTE_PATHS.token) {
    return prefillUrl ? { kind: 'token', prefillUrl } : { kind: 'token' };
  }

  if (pathname.startsWith(ROUTE_PATHS.resultPrefix)) {
    const feedToken = pathname.slice(ROUTE_PATHS.resultPrefix.length);
    if (feedToken) return { kind: 'result', feedToken };
  }

  return prefillUrl ? { kind: 'create', prefillUrl } : { kind: 'create' };
}

export function buildAppRouteHref(route: AppRoute, baseHref = getCurrentHref()): string {
  const url = new URL('/', baseHref);
  url.pathname = '/';
  url.search = '';

  if (route.kind === 'create') {
    url.hash = ROUTE_PATHS.create;
    if (route.prefillUrl) url.searchParams.set('url', route.prefillUrl);
    if (route.prefillUrl) url.hash = `${ROUTE_PATHS.create}?${url.searchParams.toString()}`;
    url.search = '';
    return url.toString();
  }

  if (route.kind === 'token') {
    url.hash = ROUTE_PATHS.token;
    if (route.prefillUrl) url.searchParams.set('url', route.prefillUrl);
    if (route.prefillUrl) url.hash = `${ROUTE_PATHS.token}?${url.searchParams.toString()}`;
    url.search = '';
    return url.toString();
  }

  url.hash = `${ROUTE_PATHS.resultPrefix}${route.feedToken}`;
  url.search = '';
  return url.toString();
}

export function useAppRoute() {
  const [route, setRoute] = useState<AppRoute>(() => readAppRoute());

  useEffect(() => {
    if (globalThis.window === undefined) return;

    const canonicalize = () => {
      const nextRoute = readAppRoute();
      setRoute(nextRoute);

      if (!globalThis.location.hash || globalThis.location.pathname !== '/') {
        replaceRoute(nextRoute);
      }
    };

    canonicalize();
    globalThis.addEventListener('popstate', canonicalize);
    globalThis.addEventListener('hashchange', canonicalize);

    return () => {
      globalThis.removeEventListener('popstate', canonicalize);
      globalThis.removeEventListener('hashchange', canonicalize);
    };
  }, []);

  const navigate = useCallback((nextRoute: AppRoute, options?: RouteNavigationOptions) => {
    if (globalThis.window === undefined) return;

    const href = buildAppRouteHref(nextRoute);
    if (options?.replace) {
      globalThis.history.replaceState({}, '', href);
    } else {
      globalThis.history.pushState({}, '', href);
    }

    setRoute(readAppRoute());
  }, []);

  return {
    route,
    navigate,
  };
}

function normalizePathname(pathname: string): string {
  if (pathname.length > 1 && pathname.endsWith('/')) {
    return pathname.slice(0, -1);
  }

  return pathname;
}

function parseHashRoute(hash: string): { pathname: string; search: string } {
  const normalizedHash = hash.startsWith('#') ? hash.slice(1) : hash;
  if (!normalizedHash) return { pathname: '/', search: '' };

  const [pathname = '/', search = ''] = normalizedHash.split('?');
  return {
    pathname: normalizePathname(pathname.startsWith('/') ? pathname : `/${pathname}`),
    search,
  };
}

function replaceRoute(route: AppRoute) {
  const href = buildAppRouteHref(route);
  globalThis.history.replaceState({}, '', href);
}

function getCurrentLocation(): RouteLocationLike {
  if (globalThis.window === undefined || !globalThis.location) {
    return { pathname: '/', search: '', hash: '' };
  }

  return {
    pathname: globalThis.location.pathname,
    search: globalThis.location.search,
    hash: globalThis.location.hash,
  };
}

function getCurrentHref(): string {
  if (globalThis.window === undefined || !globalThis.location) {
    return 'http://localhost/';
  }

  return globalThis.location.href;
}
