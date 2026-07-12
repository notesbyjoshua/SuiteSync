import { defineConfig } from 'astro/config';
import starlight from '@astrojs/starlight';
import { ion } from 'starlight-ion-theme';

export default defineConfig({
  site: 'https://notesbyjoshua.github.io',
  base: '/SuiteSync',
  integrations: [
    starlight({
      title: 'SuiteSync',
      description: 'Thoughtful suite matching for the YYGS residential experience.',
      favicon: '/yale.png',
      pagination: false,
      logo: {
        src: './src/assets/yale.png',
        replacesTitle: false,
      },
      components: {
        SocialIcons: './src/components/AdminHeaderLink.astro',
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
