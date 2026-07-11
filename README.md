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
4. Authentication configuration is managed in `supabase/config.toml`: public signup and email confirmation are disabled. Accounts are created by administrators only.
5. Passwords must contain at least eight characters.
6. Restart `npm run dev`.

Applicants sign in to an account created by a SuiteSync administrator. Public registration is disabled. The browser role can only insert a survey response when its email and user ID match the signed-in account. Row-level security prevents public clients from reading, changing, or deleting responses. Use a server-side service-role client for the future matching algorithm—never expose the service-role key in a `PUBLIC_` variable.

## Supabase CLI

The CLI is installed locally as a development dependency. Use it through `npx supabase` or the npm scripts instead of installing a global copy.

```sh
# Authenticate the CLI (opens the browser or asks for an access token)
npx supabase login

# Find the project reference in the dashboard URL or Project Settings
npx supabase link --project-ref YOUR_PROJECT_REF

# Preview migrations that have not been applied remotely
npx supabase db push --dry-run

# Apply new migrations to the linked Supabase project
npm run supabase:push
```

If a migration was previously run manually in the SQL Editor, mark only that exact version as applied before using `db push`:

```sh
npx supabase migration repair 20260711000000 --status applied
```

Repeat with `20260711010000`, `20260711020000`, or `20260711030000` only for migrations you already ran successfully. Use `npx supabase migration list` to compare local and remote history.

Local Supabase development requires Docker:

```sh
npm run supabase:start
npm run supabase:status
npm run supabase:reset
npm run supabase:stop
```

`supabase:reset` deletes and recreates only the local development database. Do not use destructive remote database reset commands on production.

## Admin matching dashboard

Run `supabase/migrations/20260711020000_create_admin_matching.sql` after the survey migrations. Sign in once with the future administrator email, then add that account as the first administrator from the Supabase SQL Editor:

```sql
insert into public.admin_users (user_id)
select id from auth.users
where email = 'your-admin-email@example.com';
```

Only the SQL Editor/service role can grant the initial admin role. Admins can open `/SuiteSync/admin/` to view survey responses, create suites, and assign or unassign applicants. Authorization is enforced by database policies and security-definer functions, not by the page UI.

## GitHub Pages

Pushes to `main` deploy automatically through `.github/workflows/deploy.yml`.

In the GitHub repository, open **Settings → Pages** and set **Source** to **GitHub Actions**. Add `PUBLIC_SUPABASE_URL` and `PUBLIC_SUPABASE_ANON_KEY` under **Settings → Secrets and variables → Actions**. The published site will be available at `https://notesbyjoshua.github.io/SuiteSync/`.

## Commands

- `npm run dev` — start the local development server
- `npm run check` — run Astro and TypeScript checks
- `npm run build` — check and build the production site
- `npm run preview` — preview the production build
