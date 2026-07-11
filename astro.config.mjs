import { defineConfig } from 'astro/config';
import starlight from '@astrojs/starlight';
import { ion } from 'starlight-ion-theme';

export default defineConfig({
  integrations: [
    starlight({
      title: 'Orbit',
      description: 'A thoughtful foundation for your next idea.',
      favicon: '/favicon.svg',
      logo: {
        src: './src/assets/logo.svg',
        replacesTitle: true,
      },
      plugins: [
        ion({
          footer: {
            text: 'Built with Astro, Starlight, and Ion.',
            links: [
              { text: 'Astro', href: 'https://astro.build', newTab: true },
              { text: 'Supabase', href: 'https://supabase.com', newTab: true },
            ],
          },
        }),
      ],
      customCss: ['./src/styles/custom.css'],
    }),
  ],
});
