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
4. Under **Authentication → URL Configuration**, set the Site URL to your deployed site and add both survey URLs as redirect URLs:
   - `http://localhost:4321/SuiteSync/survey/`
   - `https://notesbyjoshua.github.io/SuiteSync/survey/`
   - `http://localhost:4321/SuiteSync/admin/`
   - `https://notesbyjoshua.github.io/SuiteSync/admin/`
5. Keep email authentication enabled under **Authentication → Providers**.
6. Restart `npm run dev`.

Applicants sign in through a Supabase email magic link. The browser role can only insert a survey response when its email and user ID match the signed-in account. Row-level security prevents public clients from reading, changing, or deleting responses. Use a server-side service-role client for the future matching algorithm—never expose the service-role key in a `PUBLIC_` variable.

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
