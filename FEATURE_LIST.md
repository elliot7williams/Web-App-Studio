# Web App Studio Feature List

Web App Studio is a SwiftUI macOS app for building, testing, packaging, publishing, and handing off installable web apps across modern and legacy browser devices.

## Project Authoring

- HTML, CSS, JavaScript, and generated manifest editing.
- Live WebKit preview inside a device frame.
- Save and open `.webappstudio` project files.
- Import existing web app folders and zipped web app exports.
- Export generated web app folders and ZIP packages.
- Export complete handoff bundles with project source, generated files, App Store notes, deployment reports, and QR assets.
- Export Launch Checklist Packs with generated files, project source, launch index, QA checklist, major reports, store privacy materials, and optional QR assets.

## Templates, Starter Packs, And Snippets

- Built-in templates for universal starter apps, feature-phone menus, TV kiosks, and notes boards.
- Snippet library for safe areas, focus states, reduced motion, D-pad navigation, install UI, and touch targets.
- Export the current project as a reusable starter pack ZIP.
- Import starter packs from folders, ZIP files, and GitHub repository or ZIP URLs.
- Starter packs preserve project settings, custom device profiles, app code, metadata, and generated web files.

## Device Targeting

- Built-in profiles for Firefox OS-style phones, KaiOS candybar phones, compact wearables, phone PWAs, tablets, TV browsers, and desktop PWAs.
- Custom device profiles with dimensions, family, user agent, input support, notes, and preferred safe area.
- Device matrix for switching targets and reviewing compatibility scores.
- Rotate preview support.
- Safe-area simulation for phone notches, feature-phone soft keys, and TV overscan.
- Custom viewport override.

## Real-Device Testing

- Local preview server with Mac and same-Wi-Fi device URLs.
- Network Test hub with server start/stop, refresh, LAN URL copy, QR code display, QR export, and device testing steps.
- Auto-refresh server updates after project edits.
- Device test kit export with QR PNG, URL text file, and testing instructions.
- USB/removable device sync for Android, KaiOS, kiosks, mounted storage, and embedded browser transfer testing.

## PWA And Manifest Support

- Generated `manifest.webmanifest`.
- App name, short name, description, start URL, scope, language, categories, display mode, orientation, theme color, and background color controls.
- Generated 192 px and 512 px app icons.
- Optional install prompt helper.
- Optional service worker.
- Offline cache strategies: cache first, network first, and offline shell.

## Quality Checks

- Readiness checker for manifest, viewport, offline, installability, focus, safe-area, color, orientation, and device-input issues.
- Accessibility Audit panel for language, title, alt text, labels, focus styles, keyboard support, reduced motion, landmarks, headings, touch targets, and contrast reminders.
- Exportable accessibility reports with manual assistive testing checklists.
- Privacy and Permissions inspector for camera, microphone, location, notifications, clipboard, storage, Bluetooth, USB, contacts, payments, credentials, sensors, downloads, sharing, and network calls.
- Exportable privacy reports with permission evidence, recommendations, and manual review checklists.
- Store Privacy Pack export with store disclosure drafts, permission rationale copy, reviewer test notes, and privacy questionnaire JSON.
- Launch Checklist Pack export that bundles deployment, compatibility, accessibility, privacy, store-review, generated app, and editable project materials for final QA.
- Security Headers Pack export with Content Security Policy, Permissions-Policy, Netlify `_headers`, Cloudflare headers, Apache `.htaccess`, and nginx snippets.
- SEO Share Pack export with title/description guidance, Open Graph and Twitter tags, robots.txt, sitemap.xml, and SoftwareApplication JSON-LD.
- Localization Pack export with translator CSV, string catalog JSON, localized manifest starter, hreflang tags, and multi-language QA checklist.
- Analytics Plan Pack export with launch measurement goals, event taxonomy JSON, analytics QA CSV, and privacy review notes.
- Performance Budget Pack export with generated size budgets, asset CSV, runtime checklist JSON, and real-device test plan.
- Beta Feedback Pack export with tester instructions, issue template, feedback triage CSV, JSON schema, and static HTML form.
- Support Handoff Pack export with support guide, troubleshooting runbook, rollback plan, known-issues CSV, and support manifest JSON.
- Release Notes Pack export with release notes, changelog, QA delta checklist, announcement copy, and version manifest JSON.
- Compliance Review Pack export with privacy, accessibility, storage, consent, policy, and store review checklists.
- Maintenance Plan Pack export with maintenance calendar, browser drift checklist, backup checklist, and ownership manifest JSON.
- Incident Response Pack export with incident plan, log CSV, status drafts, evidence checklist, and recovery manifest JSON.
- Design System Pack export with brand tokens, design-tokens JSON, CSS variables, component checklist, and UI QA checklist.
- Project Handoff Pack export with editable `.webappstudio` source, rebuild instructions, transfer checklist, project metadata, and import manifest.
- Browser Compatibility Pack export with browser matrix CSV, lab script, JSON checklist, install checks, offline checks, and legacy target notes.
- Host Deployment Pack export with host matrix CSV, deploy checklist JSON, cache rules, and config snippets for common static hosts.
- Genius Mode with local-only project-aware suggestions that learn from marked-helpful actions over time.
- Performance budget checker for generated file sizes.
- Device compatibility scoring across built-in and custom profiles.
- Exportable deployment reports.
- Exportable device compatibility reports.

## Visual And Store Assets

- App icon controls with symbol, foreground color, and background color.
- Preview screenshot PNG export for the current device frame.
- App Store screenshot pack export for phone, tablet, desktop, TV, Firefox OS-style, KaiOS-style, and custom device profiles.
- App Store metadata document with subtitle, promo text, description, and recommended categories.

## Publishing And Release

- Publish presets for GitHub Pages, Netlify, Cloudflare Pages, static hosts/cPanel, kiosk folders, and USB/removable device packages.
- Preset-specific helper files such as `404.html`, `.nojekyll`, `_redirects`, `_headers`, and `PUBLISHING.md`.
- Release Manager for changelog drafts, build commands, ZIP packaging commands, GitHub release commands, and notarization checklist.
- Public GitHub repository and macOS release ZIP workflow.
