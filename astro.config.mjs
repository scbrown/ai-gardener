import { defineConfig } from 'astro/config';

export default defineConfig({
  site: 'https://scbrown.github.io',
  base: '/ai-gardener',
  markdown: {
    shikiConfig: {
      themes: {
        light: 'github-light',
        dark: 'github-dark',
      },
    },
  },
});
