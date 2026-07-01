import Foundation

struct WebAppSnippet: Identifiable {
    let id = UUID()
    var title: String
    var summary: String
    var tab: EditorTab
    var systemImage: String
    var code: String
}

enum SnippetLibrary {
    static let snippets: [WebAppSnippet] = [
        WebAppSnippet(
            title: "Safe Area Padding",
            summary: "Keeps content clear of notches, home indicators, and display cutouts.",
            tab: .css,
            systemImage: "rectangle.inset.filled",
            code: """

            /* Safe area support */
            .app-shell {
              padding-top: max(18px, env(safe-area-inset-top));
              padding-right: max(16px, env(safe-area-inset-right));
              padding-bottom: max(18px, env(safe-area-inset-bottom));
              padding-left: max(16px, env(safe-area-inset-left));
            }
            """
        ),
        WebAppSnippet(
            title: "Focus Ring",
            summary: "Adds clear keyboard, remote, and D-pad focus styling.",
            tab: .css,
            systemImage: "scope",
            code: """

            /* Remote and keyboard focus */
            :where(a, button, input, select, textarea, [tabindex]):focus-visible {
              outline: 3px solid #F59E0B;
              outline-offset: 3px;
              box-shadow: 0 0 0 6px rgb(245 158 11 / 18%);
            }
            """
        ),
        WebAppSnippet(
            title: "Reduced Motion",
            summary: "Respects users and devices that prefer fewer animations.",
            tab: .css,
            systemImage: "figure.walk.motion",
            code: """

            /* Reduced motion */
            @media (prefers-reduced-motion: reduce) {
              *,
              *::before,
              *::after {
                animation-duration: 0.01ms !important;
                animation-iteration-count: 1 !important;
                scroll-behavior: auto !important;
                transition-duration: 0.01ms !important;
              }
            }
            """
        ),
        WebAppSnippet(
            title: "D-pad Navigation",
            summary: "Moves focus with arrow keys for remotes, TVs, and feature phones.",
            tab: .javascript,
            systemImage: "dpad",
            code: """

            // Basic D-pad focus navigation
            const focusableItems = () =>
              [...document.querySelectorAll('a, button, input, select, textarea, [tabindex]:not([tabindex="-1"])')]
                .filter((item) => !item.disabled && item.offsetParent !== null);

            window.addEventListener('keydown', (event) => {
              const keys = ['ArrowUp', 'ArrowRight', 'ArrowDown', 'ArrowLeft'];
              if (!keys.includes(event.key)) return;

              const items = focusableItems();
              const currentIndex = Math.max(items.indexOf(document.activeElement), 0);
              const direction = event.key === 'ArrowLeft' || event.key === 'ArrowUp' ? -1 : 1;
              const next = items[(currentIndex + direction + items.length) % items.length];

              if (next) {
                event.preventDefault();
                next.focus();
              }
            });
            """
        ),
        WebAppSnippet(
            title: "Install Button",
            summary: "Adds a simple install prompt button target.",
            tab: .html,
            systemImage: "square.and.arrow.down",
            code: """

            <button class="install-button" hidden>Install app</button>
            """
        ),
        WebAppSnippet(
            title: "Touch Targets",
            summary: "Raises tappable controls to a practical minimum size.",
            tab: .css,
            systemImage: "hand.tap",
            code: """

            /* Comfortable touch targets */
            :where(button, a, input, select, textarea) {
              min-height: 44px;
            }
            """
        )
    ]
}
