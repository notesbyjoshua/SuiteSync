# SuiteSync

An Astro + Starlight app using the Ion theme and Supabase to make YYGS suite matching more thoughtful.

## Run locally

```sh
npm install
npm run dev
```

Then open `http://localhost:4321`.

## Supabase setup

1. Create a Supabase project.
2. Open the Supabase SQL Editor and run `supabase/migrations/20260711000000_create_survey_responses.sql`.
3. Copy `.env.example` to `.env` and add the project URL and publishable/anon key from **Project Settings → API**.
4. Restart `npm run dev`.

The browser role can only insert survey responses. Row-level security prevents public clients from reading, changing, or deleting responses. Use a server-side service-role client for the future matching algorithm—never expose the service-role key in a `PUBLIC_` variable.

## GitHub Pages

Pushes to `main` deploy automatically through `.github/workflows/deploy.yml`.

In the GitHub repository, open **Settings → Pages** and set **Source** to **GitHub Actions**. Add `PUBLIC_SUPABASE_URL` and `PUBLIC_SUPABASE_ANON_KEY` under **Settings → Secrets and variables → Actions**. The published site will be available at `https://notesbyjoshua.github.io/SuiteSync/`.

## Commands

- `npm run dev` — start the local development server
- `npm run check` — run Astro and TypeScript checks
- `npm run build` — check and build the production site
- `npm run preview` — preview the production build
