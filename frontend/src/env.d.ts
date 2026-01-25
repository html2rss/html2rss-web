/// <reference path="../.astro/types.d.ts" />

declare module '*.module.css' {
  const classes: Record<string, string>;
  export default classes;
}
