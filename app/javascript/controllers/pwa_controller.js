import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["installButton", "updateButton"]
  
  deferredPrompt = null
  
  connect() {
    console.log("✅ PWA controller connected")
    
    // Register service worker
    this.registerServiceWorker()
    
    // Listen for install prompt
    window.addEventListener('beforeinstallprompt', (e) => {
      console.log("📱 beforeinstallprompt event fired")
      // Prevent the mini-infobar from appearing on mobile
      e.preventDefault()
      // Stash the event so it can be triggered later
      this.deferredPrompt = e
      // Show install button
      this.showInstallButton()
    })
    
    // Listen for successful installation
    window.addEventListener('appinstalled', () => {
      console.log("✅ PWA installed successfully")
      this.hideInstallButton()
      this.deferredPrompt = null
    })
  }
  
  async registerServiceWorker() {
    if (!('serviceWorker' in navigator)) {
      console.log("❌ Service Worker not supported")
      return
    }
    
    try {
      // Register the service worker
      const registration = await navigator.serviceWorker.register('/service-worker.js', {
        scope: '/'
      })
      
      console.log("✅ Service Worker registered:", registration.scope)
      
      // Check for updates on page load
      registration.update()
      
      // Handle updates
      registration.addEventListener('updatefound', () => {
        const newWorker = registration.installing
        console.log("🔄 Service Worker update found")
        
        newWorker.addEventListener('statechange', () => {
          if (newWorker.state === 'installed' && navigator.serviceWorker.controller) {
            console.log("🆕 New Service Worker available")
            this.showUpdateButton()
          }
        })
      })
      
      // Check if there's an update waiting
      if (registration.waiting) {
        console.log("⏳ Service Worker update waiting")
        this.showUpdateButton()
      }
      
    } catch (error) {
      console.error("❌ Service Worker registration failed:", error)
    }
  }
  
  async install(event) {
    event.preventDefault()
    
    if (!this.deferredPrompt) {
      console.log("❌ No install prompt available")
      return
    }
    
    console.log("📱 Showing install prompt")
    
    // Show the install prompt
    this.deferredPrompt.prompt()
    
    // Wait for the user to respond
    const { outcome } = await this.deferredPrompt.userChoice
    console.log(`👤 User choice: ${outcome}`)
    
    if (outcome === 'accepted') {
      console.log("✅ User accepted the install prompt")
    } else {
      console.log("❌ User dismissed the install prompt")
    }
    
    // Clear the deferredPrompt
    this.deferredPrompt = null
    this.hideInstallButton()
  }
  
  update(event) {
    event.preventDefault()
    
    console.log("🔄 Activating new Service Worker")
    
    if (navigator.serviceWorker.controller) {
      navigator.serviceWorker.controller.postMessage({ type: 'SKIP_WAITING' })
    }
    
    // Reload after a short delay to allow the new SW to activate
    setTimeout(() => {
      console.log("♻️ Reloading page with new Service Worker")
      window.location.reload()
    }, 1000)
  }
  
  showInstallButton() {
    if (this.hasInstallButtonTarget) {
      this.installButtonTarget.classList.remove('hidden')
      console.log("👁 Install button shown")
    }
  }
  
  hideInstallButton() {
    if (this.hasInstallButtonTarget) {
      this.installButtonTarget.classList.add('hidden')
      console.log("🙈 Install button hidden")
    }
  }
  
  showUpdateButton() {
    if (this.hasUpdateButtonTarget) {
      this.updateButtonTarget.classList.remove('hidden')
      console.log("👁 Update button shown")
    }
  }
  
  hideUpdateButton() {
    if (this.hasUpdateButtonTarget) {
      this.updateButtonTarget.classList.add('hidden')
      console.log("🙈 Update button hidden")
    }
  }
  
  disconnect() {
    // Clean up event listeners if needed
    console.log("🔌 PWA controller disconnected")
  }
}
