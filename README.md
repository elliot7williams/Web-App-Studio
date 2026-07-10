# Web App Studio

Web App Studio is a macOS SwiftUI app for designing installable web apps across many device classes: Firefox OS-style phones, feature phones, wearables, tablets, TVs, desktop PWAs, and custom viewport targets.

## Open in Xcode

Open `WebAppStudio.xcodeproj`, select the `WebAppStudio` scheme, then run it on `My Mac`.

## What it includes

- Device presets with viewport sizes, user-agent strings, touch/pointer notes, and responsive preview sizing.
- Custom device profiles with saved dimensions, input support, user agents, notes, and preferred safe-area behavior.
- Device matrix for one-click switching between supported target profiles, with compatibility scores, target-specific flags, and exportable compatibility reports.
- Device Lab Report export with compatibility matrix, network speed estimates, lab manifest JSON, and tester runbook.
- Web API Device Matrix Pack export with API usage scan, per-device risk notes, fallback guidance, CSV, and JSON.
- User Guide & Onboarding Pack export with quick start docs, FAQ, support copy, onboarding QA, and JSON manifest.
- Observability & Error Logging Pack export with health checks, error taxonomy, logging snippet, and release monitor runbook.
- Rotate preview control for quick natural/rotated device checks.
- Safe area presets for phone notches, feature-phone soft keys, and TV overscan.
- Template gallery for universal starter, feature phone, TV kiosk, and notes-style web apps.
- Starter packs that can be exported from the current project and imported from folders, ZIP files, or GitHub repository/ZIP URLs.
- Snippet library for safe areas, focus states, reduced motion, D-pad navigation, install UI, and touch targets.
- HTML, CSS, JavaScript, and generated manifest tabs.
- Import existing web app folders that contain `index.html`.
- Import zipped web app exports that contain `index.html`.
- Live `WKWebView` preview inside a device frame.
- Preview screenshot PNG export with the current device frame and safe-area overlay.
- App Store screenshot pack export for phone, tablet, desktop, TV, and legacy-device review images.
- Local preview server with Mac and device URLs, QR code sharing, manual refresh, and auto refresh controls for same-network browser/device testing.
- Network Test hub for same-Wi-Fi testing on phones, tablets, TVs, kiosks, handhelds, and embedded browser devices.
- Device test kit export with live test URL, QR PNG, and hardware testing instructions.
- USB sync export for mounted devices, removable storage, kiosks, Android/KaiOS-style transfer testing, and embedded browser handoff.
- Publish presets for GitHub Pages, Netlify, Cloudflare Pages, static hosts, kiosk folders, and removable-device packages.
- Release Manager for changelog drafts, release commands, GitHub release steps, and macOS notarization checklists.
- Full local feature list in `FEATURE_LIST.md`.
- QR code PNG export for sharing live device-test links with testers and handoff packages.
- Deploy panel with device testing, install, hosting, and ZIP packaging steps.
- Deployment report export with readiness, performance, device profile, local URLs, and handoff checklist.
- Handoff bundle ZIP export with generated web files, editable project source, deployment report, and App Store notes.
- Launch Checklist Pack export with generated files, project source, QA checklist, launch index, and all major reports.
- Launch Risk Radar export with prioritized risk register, launch score, markdown report, CSV, and JSON.
- PWA manifest generation with display mode, orientation, theme color, and app metadata.
- Advanced manifest metadata for description, scope, language, and install categories.
- Readiness checker for manifest, viewport, offline, installability, focus, and device-input issues.
- Accessibility Audit panel with automated checks and exportable accessibility reports.
- Privacy and Permissions inspector with exportable reports for prompt-heavy browser APIs.
- Store Privacy Pack export with disclosure drafts, permission rationales, reviewer notes, and JSON questionnaire data.
- Third-Party Inventory Pack export with external URL scan, host inventory, review notes, CSV, and JSON.
- Secrets Token Audit Pack export with API key, token, credential, and private-key scanning.
- Storage & Data Retention Pack export with browser storage scan, retention questions, cleanup runbook, CSV, and JSON.
- Launch Checklist Pack export that bundles QA, deployment, compatibility, accessibility, privacy, and store-review materials.
- Security Headers Pack export with CSP, Permissions-Policy, and Netlify, Cloudflare, Apache, and nginx examples.
- SEO Share Pack export with meta tags, Open Graph/Twitter tags, robots.txt, sitemap.xml, and structured data drafts.
- Localization Pack export with translation CSV, strings JSON, localized manifest starter, hreflang tags, and language QA notes.
- Analytics Plan Pack export with event taxonomy, measurement plan, QA checklist, and privacy review notes.
- Performance Budget Pack export with asset budget CSV, runtime checks, and real-device test planning.
- Beta Feedback Pack export with tester guide, issue template, triage CSV, schema, and static feedback form.
- Support Handoff Pack export with troubleshooting, rollback, known issues, and support manifest files.
- Release Notes Pack export with user-facing notes, changelog, QA delta checklist, announcement copy, and version manifest.
- Release Evidence Vault export with score snapshot, sign-off CSV, evidence manifest, and bundled reports.
- Content Policy & Age Rating Pack export with audience review, rating-sensitive term scan, store notes, CSV, and JSON.
- Compliance Review Pack export with policy checklist, data inventory, consent copy, and reviewer questions.
- Maintenance Plan Pack export with recurring checks, browser drift review, backup checklist, and ownership manifest.
- Incident Response Pack export with severity matrix, incident log, evidence checklist, recovery manifest, and status drafts.
- Design System Pack export with design tokens, CSS variables, component checklist, and UI QA notes.
- Project Handoff Pack export with editable project source, rebuild instructions, transfer checklist, and metadata.
- Browser Compatibility Pack export with browser matrix, lab script, install checks, offline checks, and legacy target notes.
- Web API Device Matrix Pack export with camera, location, storage, worker, sensor, payment, file, share, and hardware API review.
- User Guide & Onboarding Pack export with first-run copy, troubleshooting notes, support template, and onboarding checklist.
- Observability & Error Logging Pack export with runtime error handling, offline monitoring, health signals, CSV, and JSON.
- Host Deployment Pack export with static host matrix, deploy checklist, cache rules, and hosting config snippets.
- Installability Audit Pack export with manifest review, install test script, service worker checks, and installed-launch checklist.
- Offline Resilience Pack export with cache audit, offline test matrix, fallback copy, and recovery checklist.
- QA Test Plan Pack export with tester runbook, test cases CSV, device matrix, smoke script, and JSON checklist.
- Rollback Snapshot Pack export with last known-good files, editable project source, restore checklist, cache purge notes, and manifest JSON.
- Release Dashboard with launch state, core scores, export shortcuts, and speed-test estimates for device/network classes.
- Device Lab Report pack with device coverage, speed estimates, CSV matrices, and real-device QA sign-off.
- Launch Risk Radar pack with cross-check risk scoring, triage priorities, CSV register, and JSON output.
- Offline Resilience Pack with cache readiness checks, offline scenarios, fallback copy, and JSON audit output.
- Release Evidence Vault with release proof, sign-off tracking, manifest JSON, and key QA reports.
- Third-Party Inventory Pack with external script, API, CDN, media, and host review outputs.
- Secrets Token Audit Pack with redacted findings, CSV/JSON evidence, and remediation guidance.
- Content Policy & Age Rating Pack with audience fit checks, external-link review, and store-review notes.
- Storage & Data Retention Pack with local data inventory, cache retention notes, and cleanup guidance.
- Genius Mode with local project-aware suggestions that learn from helpful actions over time.
- Performance budget panel for generated file sizes across constrained, mobile, tablet, and large-screen targets.
- Web app icon controls that generate exported 192x192 and 512x512 PNG icons.
- Optional service worker and install-prompt helper.
- Offline cache strategies for cache-first, network-first, or app-shell-only service worker exports.
- Save and open `.webappstudio` project files.
- Export flow that writes `index.html`, `manifest.webmanifest`, `styles.css`, `app.js`, optional `service-worker.js`, and a README into a new folder.
- ZIP export flow for packaging the generated web app for sharing, hosting, or device transfer.

## Verified build

This project was verified with:

```sh
xcodebuild -project WebAppStudio.xcodeproj -scheme WebAppStudio -configuration Debug -derivedDataPath /private/tmp/WebAppStudioDerivedData build
```

## Release Build

To create a local macOS release build:

```sh
xcodebuild -project WebAppStudio.xcodeproj -scheme WebAppStudio -configuration Release -derivedDataPath /private/tmp/WebAppStudioRelease build
ditto -c -k --keepParent /private/tmp/WebAppStudioRelease/Build/Products/Release/WebAppStudio.app WebAppStudio-macOS.zip
```
