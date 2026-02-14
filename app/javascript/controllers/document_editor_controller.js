import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="document-editor"
export default class extends Controller {
  static targets = ["blocksContainer", "saveIndicator"]
  static values = {
    documentId: Number,
    saveUrl: String
  }

  connect() {
    console.log("Document editor connected", {
      documentId: this.documentIdValue,
      saveUrl: this.saveUrlValue,
      authToken: this.getAuthToken(),
      blocksContainer: this.hasBlocksContainerTarget
    })
    this.setupKeyboardShortcuts()
    this.saveTimeout = null
  }

  disconnect() {
    this.clearSaveTimeout()
  }

  // Render all blocks from data
  renderBlocks(blocks) {
    this.blocksContainerTarget.innerHTML = ""
    blocks.forEach(block => {
      this.addBlockToDOM(block)
    })
  }

  // Add single block to DOM
  addBlockToDOM(block) {
    const blockElement = this.createBlockElement(block)
    this.blocksContainerTarget.appendChild(blockElement)
  }

  // Create block HTML based on type
  createBlockElement(block) {
    const wrapper = document.createElement("div")
    wrapper.classList.add("block-wrapper")
    wrapper.dataset.blockId = block.id
    wrapper.dataset.blockType = block.block_type
    wrapper.dataset.position = block.position

    const blockContent = this.renderBlockByType(block)
    wrapper.innerHTML = `
      <div class="block-controls">
        <button type="button" class="block-drag-handle" data-action="click->document-editor#startDrag">⋮⋮</button>
        <button type="button" class="block-delete" data-action="click->document-editor#deleteBlock">🗑</button>
      </div>
      <div class="block-content" data-document-editor-target="blockContent">
        ${blockContent}
      </div>
    `

    return wrapper
  }

  // Render block content by type
  renderBlockByType(block) {
    const content = block.content || {}

    switch(block.block_type) {
      case "text":
        return `<div contenteditable="true" class="text-block" data-action="blur->document-editor#saveBlock">${this.escapeHtml(content.text || "")}</div>`
      
      case "heading":
        const level = content.level || 1
        return `<h${level} contenteditable="true" class="heading-block" data-action="blur->document-editor#saveBlock">${this.escapeHtml(content.text || "")}</h${level}>`
      
      case "todo":
        const checked = content.checked ? "checked" : ""
        return `
          <div class="todo-block">
            <input type="checkbox" ${checked} data-action="change->document-editor#saveBlock">
            <span contenteditable="true" data-action="blur->document-editor#saveBlock">${this.escapeHtml(content.text || "")}</span>
          </div>
        `
      
      case "code":
        return `<pre><code contenteditable="true" class="code-block" data-action="blur->document-editor#saveBlock">${this.escapeHtml(content.code || "")}</code></pre>`
      
      case "quote":
        return `<blockquote contenteditable="true" class="quote-block" data-action="blur->document-editor#saveBlock">${this.escapeHtml(content.text || "")}</blockquote>`
      
      case "image":
        return `
          <div class="image-block">
            ${content.url ? `<img src="${content.url}" alt="${content.alt || ''}">` : '<div class="image-placeholder">Upload image</div>'}
            <input type="file" accept="image/*" data-action="change->document-editor#uploadImage" style="display:none">
            <button type="button" data-action="click->document-editor#triggerImageUpload">Upload</button>
          </div>
        `
      
      case "link":
        return `
          <div class="link-block">
            <input type="url" value="${content.url || ''}" placeholder="https://..." data-action="blur->document-editor#saveBlock">
            <div class="link-preview">${content.title || content.url || 'Enter URL'}</div>
          </div>
        `
      
      case "file":
        return `
          <div class="file-block">
            ${content.filename ? `<span class="file-name">📎 ${content.filename}</span>` : '<span class="file-placeholder">No file attached</span>'}
            <input type="file" data-action="change->document-editor#uploadFile" style="display:none">
            <button type="button" data-action="click->document-editor#triggerFileUpload">Attach</button>
          </div>
        `
      
      default:
        return `<div>Unknown block type: ${block.block_type}</div>`
    }
  }

  // Keyboard shortcuts
  setupKeyboardShortcuts() {
    document.addEventListener("keydown", this.handleKeydown.bind(this))
  }

  handleKeydown(event) {
    // Cmd+Enter or Ctrl+Enter - add new block
    if ((event.metaKey || event.ctrlKey) && event.key === "Enter") {
      event.preventDefault()
      this.addNewBlock()
    }

    // Cmd+Backspace or Ctrl+Backspace - delete focused block
    if ((event.metaKey || event.ctrlKey) && event.key === "Backspace") {
      event.preventDefault()
      this.deleteCurrentBlock()
    }
  }

  // Add new text block
  addNewBlock() {
    console.log("addNewBlock called")
    
    const newBlock = {
      id: null, // Will be assigned by server
      block_type: "text",
      content: { text: "" },
      position: this.blocksContainerTarget.children.length
    }

    console.log("Creating new block:", newBlock)

    // Optimistic UI update
    this.addBlockToDOM(newBlock)

    // Save to server
    this.createBlockOnServer(newBlock)
  }

  // Delete block
  deleteBlock(event) {
    const blockWrapper = event.target.closest(".block-wrapper")
    const blockId = blockWrapper.dataset.blockId

    if (!blockId || blockId === "null") {
      // Block not saved yet, just remove from DOM
      blockWrapper.remove()
      return
    }

    if (confirm("Delete this block?")) {
      this.deleteBlockOnServer(blockId, blockWrapper)
    }
  }

  deleteCurrentBlock() {
    const focusedBlock = document.activeElement.closest(".block-wrapper")
    if (focusedBlock) {
      const deleteButton = focusedBlock.querySelector(".block-delete")
      deleteButton?.click()
    }
  }

  // Save block on content change
  saveBlock(event) {
    console.log("saveBlock called, event.target:", event.target)
    const blockWrapper = event.target.closest(".block-wrapper")
    if (!blockWrapper) {
      console.log("No blockWrapper found")
      return
    }

    const blockId = blockWrapper.dataset.blockId
    const blockType = blockWrapper.dataset.blockType
    console.log("Block data:", { blockId, blockType })
    const content = this.extractBlockContent(blockWrapper, blockType)
    console.log("Extracted content:", content)

    if (!blockId || blockId === "null") {
      // New block, create it
      console.log("New block, calling createBlockOnServer")
      this.createBlockOnServer({ block_type: blockType, content, position: blockWrapper.dataset.position })
    } else {
      // Update existing block
      console.log("Existing block, calling debouncedSave for blockId:", blockId)
      this.debouncedSave(() => {
        console.log("Debounced save executing for blockId:", blockId)
        this.updateBlockOnServer(blockId, { content })
      })
    }
  }

  // Extract content from block DOM
  extractBlockContent(blockWrapper, blockType) {
    const blockContent = blockWrapper.querySelector(".block-content")

    switch(blockType) {
      case "text":
        return { text: blockContent.querySelector(".text-block")?.innerText || "" }
      
      case "heading":
        return { text: blockContent.querySelector(".heading-block")?.innerText || "", level: 1 }
      
      case "todo":
        return {
          text: blockContent.querySelector("span")?.innerText || "",
          checked: blockContent.querySelector("input[type=checkbox]")?.checked || false
        }
      
      case "code":
        return { code: blockContent.querySelector("code")?.innerText || "" }
      
      case "quote":
        return { text: blockContent.querySelector("blockquote")?.innerText || "" }
      
      case "link":
        return { url: blockContent.querySelector("input[type=url]")?.value || "" }
      
      default:
        return {}
    }
  }

  // Debounced save
  debouncedSave(callback) {
    this.clearSaveTimeout()
    this.showSaveIndicator("saving")
    
    this.saveTimeout = setTimeout(() => {
      callback()
    }, 300)
  }

  clearSaveTimeout() {
    if (this.saveTimeout) {
      clearTimeout(this.saveTimeout)
      this.saveTimeout = null
    }
  }

  // API calls
  async createBlockOnServer(blockData) {
    try {
      const response = await fetch(`/api/documents/${this.documentIdValue}/blocks`, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "Authorization": `Token token=${this.getAuthToken()}`
        },
        body: JSON.stringify({ block: blockData })
      })

      if (!response.ok) throw new Error("Failed to create block")

      const data = await response.json()
      // Update block ID in DOM
      const lastBlock = this.blocksContainerTarget.lastElementChild
      if (lastBlock) {
        lastBlock.dataset.blockId = data.id
      }

      this.showSaveIndicator("saved")
    } catch (error) {
      console.error("Create block error:", error)
      this.showSaveIndicator("error")
    }
  }

  async updateBlockOnServer(blockId, updates) {
    console.log("updateBlockOnServer called:", { blockId, updates })
    console.log("Auth token:", this.getAuthToken())
    
    try {
      const response = await fetch(`/api/documents/${this.documentIdValue}/blocks/${blockId}`, {
        method: "PATCH",
        headers: {
          "Content-Type": "application/json",
          "Authorization": `Token token=${this.getAuthToken()}`
        },
        body: JSON.stringify({ block: updates })
      })

      console.log("Update response status:", response.status)
      if (!response.ok) {
        const errorText = await response.text()
        console.error("Update failed:", errorText)
        throw new Error("Failed to update block")
      }

      this.showSaveIndicator("saved")
    } catch (error) {
      console.error("Update block error:", error)
      this.showSaveIndicator("error")
    }
  }

  async deleteBlockOnServer(blockId, blockElement) {
    try {
      const response = await fetch(`/api/documents/${this.documentIdValue}/blocks/${blockId}`, {
        method: "DELETE",
        headers: {
          "Authorization": `Token token=${this.getAuthToken()}`
        }
      })

      if (!response.ok) throw new Error("Failed to delete block")

      // Remove from DOM
      blockElement.remove()
      this.showSaveIndicator("saved")
    } catch (error) {
      console.error("Delete block error:", error)
      this.showSaveIndicator("error")
    }
  }

  // Save indicator
  showSaveIndicator(state) {
    if (!this.hasSaveIndicatorTarget) return

    this.saveIndicatorTarget.textContent = {
      "saving": "Saving...",
      "saved": "✓ Saved",
      "error": "⚠ Error"
    }[state] || ""

    this.saveIndicatorTarget.className = `save-indicator save-indicator--${state}`

    if (state === "saved") {
      setTimeout(() => {
        this.saveIndicatorTarget.textContent = ""
      }, 2000)
    }
  }

  // Helpers
  getAuthToken() {
    const token = document.querySelector("meta[name='auth-token']")?.content || "development_token"
    console.log("Auth token:", token) // Debug
    return token
  }

  escapeHtml(text) {
    const div = document.createElement("div")
    div.textContent = text
    return div.innerHTML
  }

  // Drag & drop placeholder methods
  startDrag(event) {
    console.log("Drag started (not implemented yet)")
  }

  triggerImageUpload(event) {
    const input = event.target.closest(".image-block").querySelector("input[type=file]")
    input?.click()
  }

  triggerFileUpload(event) {
    const input = event.target.closest(".file-block").querySelector("input[type=file]")
    input?.click()
  }

  async uploadImage(event) {
    const file = event.target.files[0]
    if (!file) return

    const blockElement = event.target.closest(".block-wrapper")
    const blockId = blockElement.dataset.blockId

    try {
      this.showSaveIndicator("saving")

      const formData = new FormData()
      formData.append("image", file)

      const response = await fetch(`/api/documents/${this.documentIdValue}/blocks/${blockId}/upload_image`, {
        method: "POST",
        headers: {
          "Authorization": `Token token=${this.getAuthToken()}`
        },
        body: formData
      })

      if (!response.ok) throw new Error("Upload failed")

      const data = await response.json()
      
      // Update block content to show uploaded image
      const imageBlock = blockElement.querySelector(".image-block")
      imageBlock.innerHTML = `
        <img src="${data.block.url}" alt="Uploaded image">
        <div class="image-meta">${data.block.filename} (${this.formatFileSize(data.block.size)})</div>
        <input type="file" accept="image/*" data-action="change->document-editor#uploadImage" style="display:none">
        <button type="button" data-action="click->document-editor#triggerImageUpload">Change</button>
      `

      this.showSaveIndicator("saved")
    } catch (error) {
      console.error("Image upload error:", error)
      this.showSaveIndicator("error")
      alert("Failed to upload image")
    }
  }

  async uploadFile(event) {
    const file = event.target.files[0]
    if (!file) return

    const blockElement = event.target.closest(".block-wrapper")
    const blockId = blockElement.dataset.blockId

    try {
      this.showSaveIndicator("saving")

      const formData = new FormData()
      formData.append("file", file)

      const response = await fetch(`/api/documents/${this.documentIdValue}/blocks/${blockId}/upload_file`, {
        method: "POST",
        headers: {
          "Authorization": `Token token=${this.getAuthToken()}`
        },
        body: formData
      })

      if (!response.ok) throw new Error("Upload failed")

      const data = await response.json()
      
      // Update block content to show uploaded file
      const fileBlock = blockElement.querySelector(".file-block")
      fileBlock.innerHTML = `
        <div class="file-info">
          <span class="file-icon">📎</span>
          <a href="${data.block.url}" download="${data.block.filename}" target="_blank">
            ${data.block.filename}
          </a>
          <span class="file-size">${this.formatFileSize(data.block.size)}</span>
        </div>
        <input type="file" data-action="change->document-editor#uploadFile" style="display:none">
        <button type="button" data-action="click->document-editor#triggerFileUpload">Change</button>
      `

      this.showSaveIndicator("saved")
    } catch (error) {
      console.error("File upload error:", error)
      this.showSaveIndicator("error")
      alert("Failed to upload file")
    }
  }

  formatFileSize(bytes) {
    if (bytes < 1024) return bytes + " B"
    if (bytes < 1024 * 1024) return (bytes / 1024).toFixed(1) + " KB"
    return (bytes / (1024 * 1024)).toFixed(1) + " MB"
  }
}
