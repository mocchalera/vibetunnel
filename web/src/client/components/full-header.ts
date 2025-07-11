/**
 * Full Header Component
 *
 * Full-width header for list view with horizontal layout
 */
import { html } from 'lit';
import { customElement } from 'lit/decorators.js';
import { HeaderBase } from './header-base.js';
import './terminal-icon.js';
import './notification-status.js';

@customElement('full-header')
export class FullHeader extends HeaderBase {
  render() {
    const runningSessions = this.runningSessions;

    return html`
      <div
        class="app-header bg-dark-bg-secondary border-b border-dark-border p-6"
        style="padding-top: max(1.5rem, calc(1.5rem + env(safe-area-inset-top)));"
      >
        <div class="flex flex-col lg:flex-row lg:items-center lg:justify-between gap-6">
          <div class="flex items-center gap-4">
            <a
              href="/"
              class="flex items-center gap-3 hover:opacity-80 transition-opacity cursor-pointer group"
              title="Go to home"
            >
              <terminal-icon size="32"></terminal-icon>
              <div>
                <h1 class="text-2xl font-bold text-accent-green font-mono group-hover:underline">
                  VibeTunnel
                </h1>
                <p class="text-dark-text-muted text-sm font-mono">
                  ${runningSessions.length} ${runningSessions.length === 1 ? 'session' : 'sessions'}
                  running
                </p>
              </div>
            </a>
          </div>

          <div class="flex flex-col sm:flex-row gap-3 sm:items-center sm:justify-between">
            <div class="flex gap-2 items-center">
              <notification-status
                @open-settings=${() =>
                  this.dispatchEvent(new CustomEvent('open-notification-settings'))}
              ></notification-status>
              <button
                class="btn-secondary font-mono text-sm px-3 sm:px-5 py-2.5"
                @click=${() => this.dispatchEvent(new CustomEvent('open-file-browser'))}
                title="Browse Files (⌘O)"
              >
                <span class="flex items-center gap-2">
                  <svg width="16" height="16" viewBox="0 0 16 16" fill="currentColor">
                    <path
                      d="M1.75 1h5.5c.966 0 1.75.784 1.75 1.75v1h4c.966 0 1.75.784 1.75 1.75v7.75A1.75 1.75 0 0113 15H3a1.75 1.75 0 01-1.75-1.75V2.75C1.25 1.784 1.784 1 1.75 1zM2.75 2.5v10.75c0 .138.112.25.25.25h10a.25.25 0 00.25-.25V5.5a.25.25 0 00-.25-.25H8.75v-2.5a.25.25 0 00-.25-.25h-5.5a.25.25 0 00-.25.25z"
                    />
                  </svg>
                  <span class="hidden sm:inline">Browse</span>
                </span>
              </button>
              <button
                class="btn-primary font-mono text-sm px-5 py-2.5 vt-create-button"
                @click=${this.handleCreateSession}
              >
                Create Session
              </button>
            </div>
            ${this.renderUserMenu()}
          </div>
        </div>
      </div>
    `;
  }

  private renderUserMenu() {
    // When no user (no-auth mode), show just a settings icon
    if (!this.currentUser) {
      return html`
        <button
          class="font-mono text-sm px-5 py-2.5 text-dark-text border border-dark-border hover:bg-dark-bg-tertiary hover:text-dark-text rounded-lg transition-all duration-200"
          @click=${this.handleOpenSettings}
          title="Settings"
        >
          <svg width="20" height="20" viewBox="0 0 20 20" fill="currentColor">
            <path fill-rule="evenodd" d="M11.49 3.17c-.38-1.56-2.6-1.56-2.98 0a1.532 1.532 0 01-2.286.948c-1.372-.836-2.942.734-2.106 2.106.54.886.061 2.042-.947 2.287-1.561.379-1.561 2.6 0 2.978a1.532 1.532 0 01.947 2.287c-.836 1.372.734 2.942 2.106 2.106a1.532 1.532 0 012.287.947c.379 1.561 2.6 1.561 2.978 0a1.533 1.533 0 012.287-.947c1.372.836 2.942-.734 2.106-2.106a1.533 1.533 0 01.947-2.287c1.561-.379 1.561-2.6 0-2.978a1.532 1.532 0 01-.947-2.287c.836-1.372-.734-2.942-2.106-2.106a1.532 1.532 0 01-2.287-.947zM10 13a3 3 0 100-6 3 3 0 000 6z" clip-rule="evenodd"/>
          </svg>
        </button>
      `;
    }

    return html`
      <div class="user-menu-container relative">
        <button
          class="font-mono text-sm px-5 py-2.5 text-dark-text border border-dark-border hover:bg-dark-bg-tertiary hover:text-dark-text rounded-lg transition-all duration-200 flex items-center gap-2"
          @click=${this.toggleUserMenu}
          title="User menu"
        >
          <span>${this.currentUser}</span>
          <svg
            width="10"
            height="10"
            viewBox="0 0 10 10"
            fill="currentColor"
            class="transition-transform ${this.showUserMenu ? 'rotate-180' : ''}"
          >
            <path d="M5 7L1 3h8z" />
          </svg>
        </button>
        ${
          this.showUserMenu
            ? html`
              <div
                class="absolute right-0 top-full mt-1 bg-dark-surface border border-dark-border rounded-lg shadow-lg py-1 z-50 min-w-36"
              >
                <div class="px-3 py-2 text-sm text-dark-text-muted border-b border-dark-border">
                  ${this.authMethod || 'authenticated'}
                </div>
                <button
                  class="w-full text-left px-3 py-2 text-sm font-mono text-dark-text hover:bg-dark-bg-secondary"
                  @click=${this.handleOpenSettings}
                >
                  Settings
                </button>
                <div class="border-t border-dark-border"></div>
                <button
                  class="w-full text-left px-3 py-2 text-sm font-mono text-status-warning hover:bg-dark-bg-secondary hover:text-status-error"
                  @click=${this.handleLogout}
                >
                  Logout
                </button>
              </div>
            `
            : ''
        }
      </div>
    `;
  }
}
