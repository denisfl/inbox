import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="sidebar"
export default class extends Controller {
  static targets = ["sidebar", "overlay"]
  
  connect() {
    console.log("✅ Sidebar controller connected!")
    console.log("Sidebar element:", this.element)
  }
  
  toggle(event) {
    console.log("🔵 Toggle called!")
    event.preventDefault()
    const sidebar = document.querySelector('.sidebar')
    const overlay = document.querySelector('.mobile-overlay')
    
    console.log("Sidebar found:", sidebar)
    console.log("Overlay found:", overlay)
    
    if (sidebar && overlay) {
      const isOpen = sidebar.classList.contains('mobile-open')
      console.log("Is open:", isOpen)
      
      if (isOpen) {
        this.close()
      } else {
        this.open()
      }
    } else {
      console.error("❌ Sidebar or overlay not found!")
    }
  }
  
  open() {
    console.log("🟢 Opening sidebar...")
    const sidebar = document.querySelector('.sidebar')
    const overlay = document.querySelector('.mobile-overlay')
    
    if (sidebar && overlay) {
      sidebar.classList.add('mobile-open')
      overlay.classList.add('active')
      document.body.style.overflow = 'hidden'
      console.log("✅ Sidebar opened!")
    }
  }
  
  close() {
    console.log("🔴 Closing sidebar...")
    const sidebar = document.querySelector('.sidebar')
    const overlay = document.querySelector('.mobile-overlay')
    
    if (sidebar && overlay) {
      sidebar.classList.remove('mobile-open')
      overlay.classList.remove('active')
      document.body.style.overflow = ''
      console.log("✅ Sidebar closed!")
    }
  }
  
  closeOnOverlay(event) {
    console.log("🟡 Overlay clicked!")
    if (event.target.classList.contains('mobile-overlay')) {
      this.close()
    }
  }
}
