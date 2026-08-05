# App Store submission assets

- `listing.md` — draft App Store Connect copy (name, subtitle, description, keywords, etc.)
- `privacy-policy.html` — privacy policy page (edit the email address, then host it)
- `support.html` — support page (edit the email address, then host it)
- `screenshots/` — App Store screenshots captured from the simulator

## Hosting the privacy policy and support page

Apple requires a live URL for both a Privacy Policy and a Support page —
App Store Connect won't let you submit without them. Easiest free option:

1. Edit the `REPLACE_WITH_YOUR_EMAIL` placeholder in both HTML files.
2. Create a public GitHub repo (e.g. `chords-notebook-site`), add these two
   files to it, then enable GitHub Pages (Settings → Pages → deploy from
   the `main` branch).
3. Your pages will be live at
   `https://<your-username>.github.io/chords-notebook-site/privacy-policy.html`
   and `.../support.html` — paste those into App Store Connect's
   "Privacy Policy URL" and "Support URL" fields.

Any other static host (Netlify, a Squarespace page, your own domain) works
just as well — GitHub Pages is just the fastest free path.
