import Foundation

struct WebAppTemplate: Identifiable, Hashable {
    var id: String
    var name: String
    var summary: String
    var bestFor: String
    var systemImage: String
    var profileName: String
    var appName: String
    var shortName: String
    var themeColor: String
    var backgroundColor: String
    var displayMode: DisplayMode
    var orientation: AppOrientation
    var html: String
    var css: String
    var javascript: String
}

@MainActor
enum TemplateLibrary {
    static let templates: [WebAppTemplate] = [
        universalStarter,
        featurePhoneMenu,
        tvKiosk,
        notesBoard
    ]

    private static let universalStarter = WebAppTemplate(
        id: "universal-starter",
        name: "Universal Starter",
        summary: "A clean installable app shell with responsive actions.",
        bestFor: "PWAs, demos, simple utilities",
        systemImage: "square.grid.2x2",
        profileName: "Firefox OS Phone",
        appName: "Pocket Weather",
        shortName: "Weather",
        themeColor: "#1D4ED8",
        backgroundColor: "#F8FAFC",
        displayMode: .standalone,
        orientation: .any,
        html: WebAppDocument.defaultHTML,
        css: WebAppDocument.defaultCSS,
        javascript: WebAppDocument.defaultJavaScript
    )

    private static let featurePhoneMenu = WebAppTemplate(
        id: "feature-phone-menu",
        name: "Feature Phone Menu",
        summary: "A compact D-pad friendly launcher for tiny screens.",
        bestFor: "KaiOS, Firefox OS, keypad devices",
        systemImage: "rectangle.grid.2x2",
        profileName: "KaiOS Candybar",
        appName: "Mini Launcher",
        shortName: "Launcher",
        themeColor: "#0F766E",
        backgroundColor: "#08111F",
        displayMode: .fullscreen,
        orientation: .portrait,
        html: """
        <!doctype html>
        <html lang="en">
        <head>
          <meta charset="utf-8">
          <meta name="viewport" content="width=device-width, initial-scale=1">
          <meta name="theme-color" content="{{THEME_COLOR}}">
          <title>{{APP_NAME}}</title>
          {{MANIFEST_LINK}}
          <style>{{CSS}}</style>
        </head>
        <body>
          <main class="phone-shell">
            <header>
              <p class="network">WEB APP</p>
              <h1>{{APP_NAME}}</h1>
            </header>

            <section class="menu" aria-label="Apps">
              <button class="tile active">Messages</button>
              <button class="tile">Weather</button>
              <button class="tile">Maps</button>
              <button class="tile">Settings</button>
            </section>

            <footer>
              <span>Select</span>
              <span>Back</span>
            </footer>
            {{INSTALL_PROMPT}}
          </main>
          <script>{{JS}}</script>
          {{SERVICE_WORKER}}
        </body>
        </html>
        """,
        css: """
        :root {
          --ink: #F8FAFC;
          --muted: #8EA2B8;
          --surface: #101C2F;
          --line: #273A55;
          --accent: #14B8A6;
          font-family: system-ui, sans-serif;
        }

        * { box-sizing: border-box; }
        body { margin: 0; min-height: 100vh; color: var(--ink); background: #08111F; }
        .phone-shell { min-height: 100vh; display: grid; grid-template-rows: auto 1fr auto auto; gap: 10px; padding: 12px; }
        header { display: grid; gap: 3px; }
        .network { margin: 0; color: var(--accent); font-size: 0.7rem; font-weight: 800; letter-spacing: 0; }
        h1 { margin: 0; font-size: 1.25rem; line-height: 1.05; }
        .menu { display: grid; grid-template-columns: 1fr 1fr; gap: 8px; align-content: center; }
        .tile { min-height: 58px; padding: 8px; border: 1px solid var(--line); border-radius: 8px; color: var(--ink); background: var(--surface); font: inherit; font-weight: 800; }
        .tile:focus-visible, .tile.active { outline: 3px solid #F59E0B; outline-offset: 1px; border-color: var(--accent); }
        footer { display: flex; justify-content: space-between; color: var(--muted); font-size: 0.78rem; font-weight: 800; }
        .install-button { min-height: 36px; border: 0; border-radius: 8px; color: #04111A; background: var(--accent); font-weight: 900; }
        """,
        javascript: """
        const tiles = [...document.querySelectorAll('.tile')];
        let index = 0;

        function selectTile(next) {
          tiles[index]?.classList.remove('active');
          index = (next + tiles.length) % tiles.length;
          tiles[index]?.classList.add('active');
          tiles[index]?.focus();
        }

        window.addEventListener('keydown', (event) => {
          if (event.key === 'ArrowRight') selectTile(index + 1);
          if (event.key === 'ArrowLeft') selectTile(index - 1);
          if (event.key === 'ArrowDown') selectTile(index + 2);
          if (event.key === 'ArrowUp') selectTile(index - 2);
        });
        """
    )

    private static let tvKiosk = WebAppTemplate(
        id: "tv-kiosk",
        name: "TV Kiosk",
        summary: "Large readable panels and remote-friendly focus states.",
        bestFor: "TV browsers, lobby screens, dashboards",
        systemImage: "tv",
        profileName: "TV Browser",
        appName: "Studio Board",
        shortName: "Board",
        themeColor: "#2563EB",
        backgroundColor: "#F6F7FB",
        displayMode: .fullscreen,
        orientation: .landscape,
        html: """
        <!doctype html>
        <html lang="en">
        <head>
          <meta charset="utf-8">
          <meta name="viewport" content="width=device-width, initial-scale=1">
          <meta name="theme-color" content="{{THEME_COLOR}}">
          <title>{{APP_NAME}}</title>
          {{MANIFEST_LINK}}
          <style>{{CSS}}</style>
        </head>
        <body>
          <main class="tv-shell">
            <section class="headline">
              <p>Live board</p>
              <h1>{{APP_NAME}}</h1>
            </section>
            <section class="panels">
              <button class="panel">Schedule<br><strong>12:30</strong></button>
              <button class="panel">Queue<br><strong>8 items</strong></button>
              <button class="panel">Status<br><strong>Ready</strong></button>
            </section>
            {{INSTALL_PROMPT}}
          </main>
          <script>{{JS}}</script>
          {{SERVICE_WORKER}}
        </body>
        </html>
        """,
        css: """
        :root { --ink: #111827; --muted: #5B6472; --surface: #FFFFFF; --accent: #2563EB; font-family: system-ui, sans-serif; }
        * { box-sizing: border-box; }
        body { margin: 0; min-height: 100vh; color: var(--ink); background: #F6F7FB; }
        .tv-shell { min-height: 100vh; display: grid; grid-template-rows: auto 1fr auto; gap: 32px; padding: 48px 64px; }
        .headline p { margin: 0 0 8px; color: var(--accent); font-size: 1.2rem; font-weight: 900; text-transform: uppercase; letter-spacing: 0; }
        h1 { margin: 0; font-size: clamp(3.5rem, 8vw, 7rem); line-height: 0.95; letter-spacing: 0; }
        .panels { display: grid; grid-template-columns: repeat(3, 1fr); gap: 24px; align-content: end; }
        .panel { min-height: 210px; padding: 28px; border: 2px solid #D8DEE9; border-radius: 8px; color: var(--ink); background: var(--surface); text-align: left; font: inherit; font-size: 2rem; font-weight: 800; }
        .panel strong { display: block; margin-top: 12px; font-size: 3.2rem; color: var(--accent); }
        .panel:focus-visible { outline: 8px solid #F59E0B; outline-offset: 4px; }
        .install-button { justify-self: start; min-height: 56px; padding: 0 28px; border: 0; border-radius: 8px; color: white; background: var(--accent); font: inherit; font-weight: 900; }
        """,
        javascript: """
        const panels = [...document.querySelectorAll('.panel')];
        panels[0]?.focus();
        panels.forEach((panel) => panel.addEventListener('click', () => panels.forEach((item) => item.toggleAttribute('aria-current', item === panel))));
        """
    )

    private static let notesBoard = WebAppTemplate(
        id: "notes-board",
        name: "Notes Board",
        summary: "A simple local-first notes layout with cards.",
        bestFor: "Tablets, desktop PWAs, productivity apps",
        systemImage: "note.text",
        profileName: "Tablet Web App",
        appName: "Field Notes",
        shortName: "Notes",
        themeColor: "#7C3AED",
        backgroundColor: "#F7F7FB",
        displayMode: .standalone,
        orientation: .any,
        html: """
        <!doctype html>
        <html lang="en">
        <head>
          <meta charset="utf-8">
          <meta name="viewport" content="width=device-width, initial-scale=1">
          <meta name="theme-color" content="{{THEME_COLOR}}">
          <title>{{APP_NAME}}</title>
          {{MANIFEST_LINK}}
          <style>{{CSS}}</style>
        </head>
        <body>
          <main class="notes-shell">
            <header>
              <h1>{{APP_NAME}}</h1>
              <button id="add-note">New</button>
            </header>
            <section class="notes" aria-live="polite">
              <article contenteditable="true">Prototype the install flow.</article>
              <article contenteditable="true">Test small-screen navigation.</article>
              <article contenteditable="true">Export icons before review.</article>
            </section>
            {{INSTALL_PROMPT}}
          </main>
          <script>{{JS}}</script>
          {{SERVICE_WORKER}}
        </body>
        </html>
        """,
        css: """
        :root { --ink: #181C2A; --muted: #60677A; --surface: #FFFFFF; --line: #DDE1EA; --accent: #7C3AED; font-family: system-ui, sans-serif; }
        * { box-sizing: border-box; }
        body { margin: 0; min-height: 100vh; color: var(--ink); background: #F7F7FB; }
        .notes-shell { min-height: 100vh; display: grid; grid-template-rows: auto 1fr auto; gap: 18px; padding: max(18px, env(safe-area-inset-top)) max(18px, env(safe-area-inset-right)) max(18px, env(safe-area-inset-bottom)) max(18px, env(safe-area-inset-left)); }
        header { display: flex; align-items: center; justify-content: space-between; gap: 12px; }
        h1 { margin: 0; font-size: clamp(1.8rem, 7vw, 4rem); letter-spacing: 0; }
        button { min-height: 44px; padding: 0 18px; border: 0; border-radius: 8px; color: white; background: var(--accent); font: inherit; font-weight: 800; }
        .notes { display: grid; grid-template-columns: repeat(auto-fit, minmax(170px, 1fr)); gap: 12px; align-content: start; }
        article { min-height: 140px; padding: 14px; border: 1px solid var(--line); border-radius: 8px; background: var(--surface); line-height: 1.45; }
        article:focus { outline: 3px solid #F59E0B; outline-offset: 2px; }
        """,
        javascript: """
        const notes = document.querySelector('.notes');
        document.querySelector('#add-note')?.addEventListener('click', () => {
          const note = document.createElement('article');
          note.contentEditable = 'true';
          note.textContent = 'New note';
          notes?.prepend(note);
          note.focus();
        });
        """
    )
}
