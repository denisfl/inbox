import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="theme"
export default class extends Controller {
  static targets = ["toggle"]
  
  connect() {
    // Initialize theme from localStorage or system preference
    this.initializeTheme()
    
    // Listen for system theme changes
    if (window.matchMedia) {
      const mediaQuery = window.matchMedia('(prefers-color-scheme: dark)')
      mediaQuery.addEventListener('change', (e) => {
        if (!localStorage.getItem('theme')) {
          this.applyTheme(e.matches ? 'dark' : 'light')
        }
      })
    }
  }
  
  initializeTheme() {
    const savedTheme = localStorage.getItem('theme')
    const systemPrefersDark = window.matchMedia('(prefers-color-scheme: dark)').matches
    const theme = savedTheme || (systemPrefersDark ? 'dark' : 'light')
    
    this.applyTheme(theme)
    this.updateToggleButton(theme)
  }
  
  toggle(event) {
    const currentTheme = document.documentElement.getAttribute('data-theme') || 'light'
    const newTheme = currentTheme === 'light' ? 'dark' : 'light'
    
    this.applyTheme(newTheme)
    this.updateToggleButton(newTheme)
    
    // Save to localStorage
    localStorage.setItem('theme', newTheme)
  }
  
  applyTheme(theme) {
    document.documentElement.setAttribute('data-theme', theme)
  }
  
  updateToggleButton(theme) {
    if (!this.hasToggleTarget) return
    
    const button = this.toggleTarget
    const icon = button.querySelector('.theme-icon')
    
    if (!icon) return
    
    if (theme === 'dark') {
      // Switch to sun icon
      icon.innerHTML = '<path stroke-linecap="round" stroke-linejoin="round" d="M12 3v2.25m6.364.386l-1.591 1.591M21 12h-2.25m-.386 6.364l-1.591-1.591M12 18.75V21m-4.773-4.227l-1.591 1.591M5.25 12H3m4.227-4.773L5.636 5.636M15.75 12a3.75 3.75 0 11-7.5 0 3.75 3.75 0 017.5 0z" />'
      button.title = 'Switch to light mode'
      button.setAttribute('aria-label', 'Switch to light mode')
      icon.dataset.themeIcon = 'sun'
    } else {
      // Switch to moon icon
      icon.innerHTML = '<path stroke-linecap="round" stroke-linejoin="round" d="M21.752 15.002A9.718 9.718 0 0118 15.75c-5.385 0-9.75-4.365-9.75-9.75 0-1.33.266-2.597.748-3.752A9.753 9.753 0 003 11.25C3 16.635 7.365 21 12.75 21a9.753 9.753 0 009.002-5.998z" />'
      button.title = 'Switch to dark mode'
      button.setAttribute('aria-label', 'Switch to dark mode')
      icon.dataset.themeIcon = 'moon'
    }
  }
}
