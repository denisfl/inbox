import { Controller } from "@hotwired/stimulus";

// Connects to data-controller="document-editor"
export default class extends Controller {
  static targets = ["blocksContainer", "saveIndicator"];
  static values = {
    documentId: Number,
    saveUrl: String,
  };

  connect() {
    console.log("Document editor connected", {
      documentId: this.documentIdValue,
      saveUrl: this.saveUrlValue,
      authToken: this.getAuthToken(),
      blocksContainer: this.hasBlocksContainerTarget,
    });
    this.setupKeyboardShortcuts();
    this.setupDragAndDrop();
    this.setupPasteHandler();
    this.saveTimeout = null;
    this.draggedBlock = null;
    
    // Auto-focus first editable block after short delay
    setTimeout(() => {
      this.autoFocusFirstBlock();
    }, 150);
  }

  disconnect() {
    this.clearSaveTimeout();
    this.draggedBlock = null;
  }
  
  // Auto-focus the first contenteditable block
  autoFocusFirstBlock() {
    // Don't auto-focus if user already focused something
    const activeElement = document.activeElement;
    if (activeElement && activeElement.closest('.blocks-container')) {
      console.log('User already focused an element, skipping auto-focus');
      return;
    }
    
    // Find first contenteditable element
    const firstEditable = this.blocksContainerTarget.querySelector('[contenteditable="true"]');
    if (firstEditable) {
      console.log('Auto-focusing first block');
      firstEditable.focus();
      
      // Move cursor to end of content
      const range = document.createRange();
      const sel = window.getSelection();
      
      // Select all content
      range.selectNodeContents(firstEditable);
      // Collapse to end (false = end, true = start)
      range.collapse(false);
      
      // Apply selection
      sel.removeAllRanges();
      sel.addRange(range);
    }
  }

  // Render all blocks from data
  renderBlocks(blocks) {
    this.blocksContainerTarget.innerHTML = "";
    blocks.forEach((block) => {
      this.addBlockToDOM(block);
    });
  }

  // Add single block to DOM
  addBlockToDOM(block) {
    const blockElement = this.createBlockElement(block);
    this.blocksContainerTarget.appendChild(blockElement);
  }

  // Create block HTML based on type
  createBlockElement(block) {
    const wrapper = document.createElement("div");
    wrapper.classList.add("block-wrapper");
    wrapper.dataset.blockId = block.id;
    wrapper.dataset.blockType = block.block_type;
    wrapper.dataset.position = block.position;

    const blockContent = this.renderBlockByType(block);
    wrapper.innerHTML = `
      <div class="block-controls">
        <button type="button" class="block-drag-handle" draggable="true">⋮⋮</button>
        <button type="button" class="block-delete" data-action="click->document-editor#deleteBlock">🗑</button>
      </div>
      <div class="block-content" data-document-editor-target="blockContent">
        ${blockContent}
      </div>
    `;

    return wrapper;
  }

  // Render block content by type
  renderBlockByType(block) {
    const content = block.content || {};

    switch (block.block_type) {
      case "text":
        // Uses the markdown-editor Stimulus controller; Stimulus auto-connects after innerHTML set
        return `<div class="text-block"
          data-controller="markdown-editor"
          data-markdown-editor-block-id-value="${block.id || ''}"
          data-markdown-editor-document-id-value="${this.documentIdValue}">
          <div class="markdown-preview" data-markdown-editor-target="preview" data-action="dblclick->markdown-editor#startEditing" title="Double-click to edit">${this.escapeHtml(content.text || "")}</div>
          <div class="hidden markdown-edit-area" data-markdown-editor-target="editArea">
            <textarea class="markdown-textarea" rows="6" placeholder="Write Markdown here…" data-markdown-editor-target="textarea" data-action="blur->markdown-editor#saveBlock keydown->markdown-editor#handleKeydown">${this.escapeHtml(content.text || "")}</textarea>
            <div class="markdown-edit-actions">
              <span class="markdown-hint">⌘↵ save · Esc cancel</span>
              <button type="button" class="btn btn-sm" data-action="click->markdown-editor#cancelEdit">Cancel</button>
            </div>
          </div>
        </div>`;

      case "heading":
        const level = content.level || 1;
        return `<h${level} contenteditable="true" class="heading-block" data-action="blur->document-editor#saveBlock">${this.escapeHtml(content.text || "")}</h${level}>`;

      case "todo":
        const checked = content.checked ? "checked" : "";
        return `
          <div class="todo-block">
            <input type="checkbox" ${checked} data-action="change->document-editor#saveBlock">
            <span contenteditable="true" data-action="blur->document-editor#saveBlock">${this.escapeHtml(content.text || "")}</span>
          </div>
        `;

      case "code":
        return `<pre><code contenteditable="true" class="code-block" data-action="blur->document-editor#saveBlock">${this.escapeHtml(content.code || "")}</code></pre>`;

      case "quote":
        return `<blockquote contenteditable="true" class="quote-block" data-action="blur->document-editor#saveBlock">${this.escapeHtml(content.text || "")}</blockquote>`;

      case "image":
        return `
          <div class="image-block">
            ${content.url ? `<img src="${content.url}" alt="${content.alt || ""}">` : '<div class="image-placeholder">Upload image</div>'}
            <input type="file" accept="image/*" data-action="change->document-editor#uploadImage" style="display:none">
            <button type="button" data-action="click->document-editor#triggerImageUpload">Upload</button>
          </div>
        `;

      case "link":
        return `
          <div class="link-block">
            <input type="url" value="${content.url || ""}" placeholder="https://..." data-action="blur->document-editor#saveBlock">
            <div class="link-preview">${content.title || content.url || "Enter URL"}</div>
          </div>
        `;

      case "file":
        return `
          <div class="file-block">
            ${content.filename ? `<span class="file-name">📎 ${content.filename}</span>` : '<span class="file-placeholder">No file attached</span>'}
            <input type="file" data-action="change->document-editor#uploadFile" style="display:none">
            <button type="button" data-action="click->document-editor#triggerFileUpload">Attach</button>
          </div>
        `;

      default:
        return `<div>Unknown block type: ${block.block_type}</div>`;
    }
  }

  // Keyboard shortcuts
  setupKeyboardShortcuts() {
    document.addEventListener("keydown", this.handleKeydown.bind(this));
  }

  handleKeydown(event) {
    console.log('🎹 Key pressed:', event.key, 'Meta:', event.metaKey, 'Ctrl:', event.ctrlKey, 'Shift:', event.shiftKey);
    
    // Cmd+Enter or Ctrl+Enter - add new block
    if ((event.metaKey || event.ctrlKey) && event.key === "Enter") {
      event.preventDefault();
      this.addNewBlock();
      return;
    }

    // Cmd+Backspace or Ctrl+Backspace - delete focused block
    if ((event.metaKey || event.ctrlKey) && event.key === "Backspace") {
      event.preventDefault();
      this.deleteCurrentBlock();
      return;
    }

    // Keyboard shortcuts: Cmd+Shift+1 through Cmd+Shift+8
    if ((event.metaKey || event.ctrlKey) && event.shiftKey) {
      const shortcuts = {
        '1': 'text',
        '2': 'heading',
        '3': 'todo',
        '4': 'code',
        '5': 'quote',
        '6': 'link',
        '7': 'file',
        '8': 'image'
      };

      if (shortcuts[event.key]) {
        event.preventDefault();
        const type = shortcuts[event.key];
        const content = this.getDefaultContentForType(type);
        
        const newBlock = {
          id: null,
          block_type: type,
          content: content,
        };
        
        this.addBlockToDOM(newBlock);
        this.createBlockOnServer(newBlock).then(() => {
          const lastBlock = this.blocksContainerTarget.lastElementChild;
          if (lastBlock) {
            const contentEditable = lastBlock.querySelector("[contenteditable=true]");
            if (contentEditable) {
              contentEditable.focus();
            }
          }
        });
        return;
      }
    }

    // Handle Enter key in contenteditable blocks
    if (event.key === 'Enter' && !event.shiftKey && !event.metaKey && !event.ctrlKey) {
      const activeElement = document.activeElement;
      const blockWrapper = activeElement.closest(".block-wrapper");
      
      if (blockWrapper && activeElement.hasAttribute('contenteditable')) {
        const blockType = blockWrapper.dataset.blockType;
        
        // For TODO blocks, create new TODO block
        if (blockType === 'todo') {
          event.preventDefault();
          this.handleTodoEnter(blockWrapper, activeElement);
          return;
        }
        
        // For text blocks, advanced markdown processing
        if (blockType === 'text') {
          const handled = this.handleSmartEnter(event, blockWrapper, activeElement);
          if (handled) return;
        }
      }
    }

    // Detect slash commands
    if (event.key === '/') {
      const activeElement = document.activeElement;
      const blockWrapper = activeElement?.closest(".block-wrapper");
      
      if (blockWrapper && blockWrapper.dataset.blockType === 'text') {
        const text = activeElement.innerText || '';
        // Only show menu if at start of line or after whitespace
        if (text.length === 0 || text.endsWith(' ') || text.endsWith('\n')) {
          setTimeout(() => {
            this.handleSlashCommand(activeElement);
          }, 10);
        }
      }
    }

    // Detect markdown shortcuts on Space key
    if (event.key === ' ') {
      const activeElement = document.activeElement;
      const blockWrapper = activeElement?.closest(".block-wrapper");
      
      if (blockWrapper && blockWrapper.dataset.blockType === 'text') {
        const text = (activeElement.innerText || '').trim();
        
        // Check for markdown patterns
        if (this.isMarkdownShortcut(text)) {
          event.preventDefault();
          this.convertMarkdownShortcut(blockWrapper, text);
        }
      }
    }
  }

  // ========== SMART MARKDOWN PROCESSING ==========
  
  // Handle Enter key with full Markdown support
  handleSmartEnter(event, blockWrapper, activeElement) {
    const fullText = activeElement.innerText || '';
    const cursorPosition = this.getCursorPosition(activeElement);
    
    // Get current line (text before cursor since last newline)
    const textBeforeCursor = fullText.substring(0, cursorPosition);
    const lastNewlineIndex = textBeforeCursor.lastIndexOf('\n');
    const currentLineStart = lastNewlineIndex >= 0 ? lastNewlineIndex + 1 : 0;
    const currentLine = fullText.substring(currentLineStart, cursorPosition).trim();
    
    console.log('📝 Smart Enter:', { currentLine, cursorPosition });
    
    // Check for markdown patterns
    const markdownMatch = this.detectMarkdownPattern(currentLine);
    
    if (markdownMatch) {
      event.preventDefault();
      console.log('✅ Markdown detected:', markdownMatch);
      this.handleMarkdownLine(blockWrapper, activeElement, markdownMatch, currentLineStart, cursorPosition);
      return true;
    }
    
    // Check for double Enter (empty line before cursor)
    if (currentLine === '' && textBeforeCursor.endsWith('\n')) {
      event.preventDefault();
      console.log('✅ Double Enter detected');
      this.handleDoubleEnter(blockWrapper, activeElement, cursorPosition);
      return true;
    }
    
    return false;
  }
  
  // Detect markdown patterns in a line
  detectMarkdownPattern(line) {
    const patterns = [
      // Standard Markdown headings
      { regex: /^(#{1,3})\s+(.*)$/, handler: (m) => ({ type: 'heading', level: m[1].length, text: m[2] }) },
      // Slash command headings
      { regex: /^\/(h[123])(?:\s+(.*))?$/, handler: (m) => ({ type: 'heading', level: parseInt(m[1][1]), text: m[2] || '' }) },
      // TODO items
      { regex: /^-\s*\[\s*\](?:\s+(.*))?$/, handler: (m) => ({ type: 'todo', text: m[1] || '', checked: false }) },
      // Slash todo
      { regex: /^\/todo(?:\s+(.*))?$/, handler: (m) => ({ type: 'todo', text: m[1] || '', checked: false }) },
      // Code blocks
      { regex: /^```(?:\s+(.*))?$/, handler: (m) => ({ type: 'code', code: m[1] || '' }) },
      // Slash code
      { regex: /^\/code(?:\s+(.*))?$/, handler: (m) => ({ type: 'code', code: m[1] || '' }) },
      // Blockquotes
      { regex: /^>(?:\s+(.*))?$/, handler: (m) => ({ type: 'quote', text: m[1] || '' }) },
      // Slash quote
      { regex: /^\/quote(?:\s+(.*))?$/, handler: (m) => ({ type: 'quote', text: m[1] || '' }) },
    ];
    
    for (const pattern of patterns) {
      const match = line.match(pattern.regex);
      if (match) {
        return pattern.handler(match);
      }
    }
    
    return null;
  }
  
  // Handle a line with markdown syntax
  handleMarkdownLine(blockWrapper, activeElement, markdownMatch, lineStart, cursorPosition) {
    const fullText = activeElement.innerText || '';
    const textBeforeMarkdown = fullText.substring(0, lineStart).trimEnd();
    const textAfterCursor = fullText.substring(cursorPosition).trimStart();
    
    console.log('Processing markdown:', { textBeforeMarkdown, markdownMatch, textAfterCursor });
    
    // If there's text before the markdown line, we need to split
    if (textBeforeMarkdown.length > 0) {
      // Keep current block as text with content before markdown
      activeElement.innerText = textBeforeMarkdown;
      this.saveBlock({ target: activeElement });
      
      // Create new block for markdown line
      const currentPosition = parseInt(blockWrapper.dataset.position);
      this.createNewBlockAfter(currentPosition, markdownMatch.type, markdownMatch, textAfterCursor);
    } else {
      // Convert current block to markdown type
      this.convertBlockToType(blockWrapper, markdownMatch.type, markdownMatch, textAfterCursor);
    }
  }
  
  // Handle double Enter (paragraph break)
  handleDoubleEnter(blockWrapper, activeElement, cursorPosition) {
    const fullText = activeElement.innerText || '';
    const textBeforeCursor = fullText.substring(0, cursorPosition).trimEnd();
    const textAfterCursor = fullText.substring(cursorPosition).trimStart();
    
    console.log('Double Enter split:', { before: textBeforeCursor, after: textAfterCursor });
    
    // Update current block with text before cursor
    activeElement.innerText = textBeforeCursor;
    this.saveBlock({ target: activeElement });
    
    // Create new text block with remaining text
    const currentPosition = parseInt(blockWrapper.dataset.position);
    this.createNewBlockAfter(currentPosition, 'text', { text: textAfterCursor }, '');
  }
  
  // Create a new block after specified position
  createNewBlockAfter(afterPosition, blockType, content, additionalText = '') {
    const newBlock = {
      id: null,
      block_type: blockType,
      content: this.formatBlockContent(blockType, content, additionalText),
    };
    
    console.log('Creating new block:', newBlock);
    
    return this.createBlockOnServer(newBlock).then((response) => {
      if (!response) {
        console.error('❌ No response from createBlockOnServer');
        throw new Error('No response from server');
      }
      
      // Insert into DOM after current block
      const currentBlock = this.blocksContainerTarget.querySelector(`[data-position="${afterPosition}"]`);
      if (currentBlock) {
        const newElement = this.createBlockElement({ id: response.id, ...newBlock });
        currentBlock.insertAdjacentElement('afterend', newElement);
        
        // Reindex positions
        this.reindexBlockPositions();
        
        // Focus new block
        const editableElement = newElement.querySelector('[contenteditable]');
        if (editableElement) {
          editableElement.focus();
          // Move cursor to end
          this.moveCursorToEnd(editableElement);
        }
      }
      
      return response;  // Return for chaining
    }).catch(error => {
      console.error('❌ Failed to create new block:', error);
      throw error;  // Re-throw for sequential handler
    });
  }
  
  // Convert current block to different type
  convertBlockToType(blockWrapper, blockType, content, additionalText = '') {
    const blockId = blockWrapper.dataset.blockId;
    
    // If block is not saved yet, can't convert it - need to reload approach
    if (!blockId || blockId === 'null') {
      console.warn('⚠️ Cannot convert unsaved block, needs reload approach');
      return;
    }
    
    // Clear current content
    const editableElement = blockWrapper.querySelector('[contenteditable]');
    if (editableElement) {
      editableElement.innerText = '';
    }
    
    // Update block type and content
    const updates = {
      block_type: blockType,
      content: this.formatBlockContent(blockType, content, additionalText)
    };
    
    console.log('Converting block:', { blockId, updates });
    
    this.updateBlockOnServer(blockId, updates).then(() => {
      // Reload the block with new type
      location.reload(); // TODO: Better way - rebuild block element without reload
    });
  }
  
  // Format content based on block type
  formatBlockContent(blockType, matchData, additionalText = '') {
    switch (blockType) {
      case 'heading':
        return {
          text: (matchData.text || '') + (additionalText ? '\n' + additionalText : ''),
          level: matchData.level
        };
      case 'todo':
        return {
          text: (matchData.text || '') + (additionalText ? '\n' + additionalText : ''),
          checked: matchData.checked || false
        };
      case 'code':
        return {
          code: (matchData.code || '') + (additionalText ? '\n' + additionalText : '')
        };
      case 'quote':
        return {
          text: (matchData.text || '') + (additionalText ? '\n' + additionalText : '')
        };
      case 'text':
      default:
        return {
          text: (matchData.text || '') + (additionalText ? '\n' + additionalText : '')
        };
    }
  }
  
  // Get cursor position in contenteditable element
  getCursorPosition(element) {
    const selection = window.getSelection();
    if (selection.rangeCount === 0) return 0;
    
    const range = selection.getRangeAt(0);
    const preCaretRange = range.cloneRange();
    preCaretRange.selectNodeContents(element);
    preCaretRange.setEnd(range.endContainer, range.endOffset);
    
    return preCaretRange.toString().length;
  }
  
  // Move cursor to end of element
  moveCursorToEnd(element) {
    const range = document.createRange();
    const sel = window.getSelection();
    range.selectNodeContents(element);
    range.collapse(false);
    sel.removeAllRanges();
    sel.addRange(range);
  }
  
  // Reindex all block positions
  reindexBlockPositions() {
    const blocks = Array.from(this.blocksContainerTarget.querySelectorAll('.block-wrapper'));
    blocks.forEach((block, index) => {
      block.dataset.position = index;
    });
  }
  
  // ========== END SMART MARKDOWN PROCESSING ==========

  // Add new text block
  addNewBlock() {
    console.log("addNewBlock called");

    const newBlock = {
      id: null, // Will be assigned by server
      block_type: "text",
      content: { text: "" },
      position: this.blocksContainerTarget.children.length,
    };

    console.log("Creating new block:", newBlock);

    // Optimistic UI update
    this.addBlockToDOM(newBlock);

    // Save to server
    this.createBlockOnServer(newBlock);
  }

  // Handle Enter key in todo blocks - split multi-line content into separate blocks
  handleTodoEnter(blockWrapper, activeElement) {
    console.log("handleTodoEnter called");
    
    const text = (activeElement.innerText || '').trim();
    const blockId = blockWrapper.dataset.blockId;
    const checked = blockWrapper.querySelector('input[type=checkbox]')?.checked || false;
    
    // If there's text, save current block first
    if (text && blockId && blockId !== 'null') {
      this.updateBlockOnServer(blockId, { 
        content: { text: text, checked: checked } 
      });
    }
    
    // Create a new todo block below
    // Don't send position - let server auto-assign via set_default_position to avoid race conditions
    const newBlock = {
      id: null,
      block_type: "todo",
      content: { text: "", checked: false },
    };
    
    // Insert new block after current one in DOM
    const newBlockElement = this.createBlockElement(newBlock);
    blockWrapper.after(newBlockElement);
    
    // Save to server and focus after DOM update
    this.createBlockOnServer(newBlock).then(() => {
      // Use setTimeout to ensure DOM is fully rendered
      setTimeout(() => {
        const todoSpan = newBlockElement.querySelector('span[contenteditable=true]');
        if (todoSpan) {
          todoSpan.focus();
          this.moveCursorToEnd(todoSpan);
          console.log('✅ Focused new TODO block');
        }
      }, 50);
    });
  }

  // Delete block
  deleteBlock(event) {
    const blockWrapper = event.target.closest(".block-wrapper");
    const blockId = blockWrapper.dataset.blockId;

    if (!blockId || blockId === "null") {
      // Block not saved yet, just remove from DOM
      blockWrapper.remove();
      return;
    }

    if (confirm("Delete this block?")) {
      this.deleteBlockOnServer(blockId, blockWrapper);
    }
  }

  deleteCurrentBlock() {
    const focusedBlock = document.activeElement.closest(".block-wrapper");
    if (focusedBlock) {
      const deleteButton = focusedBlock.querySelector(".block-delete");
      deleteButton?.click();
    }
  }

  // Save block on content change
  saveBlock(event) {
    console.log("saveBlock called, event.target:", event.target);
    const blockWrapper = event.target.closest(".block-wrapper");
    if (!blockWrapper) {
      console.log("No blockWrapper found");
      return;
    }

    const blockId = blockWrapper.dataset.blockId;
    const blockType = blockWrapper.dataset.blockType;
    console.log("Block data:", { blockId, blockType });
    const content = this.extractBlockContent(blockWrapper, blockType);
    console.log("Extracted content:", content);

    if (!blockId || blockId === "null") {
      // New block, create it
      console.log("New block, calling createBlockOnServer");
      this.createBlockOnServer({
        block_type: blockType,
        content,
      });
    } else {
      // Update existing block
      console.log(
        "Existing block, calling debouncedSave for blockId:",
        blockId,
      );
      this.debouncedSave(() => {
        console.log("Debounced save executing for blockId:", blockId);
        this.updateBlockOnServer(blockId, { content });
      });
    }
  }

  // Extract content from block DOM
  extractBlockContent(blockWrapper, blockType) {
    const blockContent = blockWrapper.querySelector(".block-content");

    switch (blockType) {
      case "text":
        // markdown-editor controller owns saving; this fallback reads textarea if present
        return {
          text: blockContent.querySelector("textarea[data-markdown-editor-target='textarea']")?.value
               || blockContent.querySelector(".text-block")?.innerText
               || "",
        };

      case "heading":
        return {
          text: blockContent.querySelector(".heading-block")?.innerText || "",
          level: 1,
        };

      case "todo":
        return {
          text: blockContent.querySelector("span")?.innerText || "",
          checked:
            blockContent.querySelector("input[type=checkbox]")?.checked ||
            false,
        };

      case "code":
        return { code: blockContent.querySelector("code")?.innerText || "" };

      case "quote":
        return {
          text: blockContent.querySelector("blockquote")?.innerText || "",
        };

      case "link":
        return {
          url: blockContent.querySelector("input[type=url]")?.value || "",
        };

      default:
        return {};
    }
  }

  // Save document title
  saveTitle(event) {
    const titleElement = event.target;
    const newTitle = titleElement.innerText.trim();
    const documentId = titleElement.dataset.documentId;
    
    console.log('Saving title:', { documentId, newTitle });
    
    this.debouncedSave(() => {
      console.log('Debounced title save executing');
      this.updateDocumentTitle(documentId, newTitle);
    });
  }

  async updateDocumentTitle(documentId, title) {
    try {
      const response = await fetch(
        `/api/documents/${documentId}`,
        {
          method: 'PATCH',
          headers: {
            'Content-Type': 'application/json',
            Authorization: `Token token=${this.getAuthToken()}`,
          },
          body: JSON.stringify({ document: { title } }),
        },
      );

      if (!response.ok) {
        throw new Error('Failed to update title');
      }

      this.showSaveIndicator('saved');
      console.log('✅ Title saved');
    } catch (error) {
      console.error('Title update error:', error);
      this.showSaveIndicator('error');
    }
  }

  // Debounced save
  debouncedSave(callback) {
    this.clearSaveTimeout();
    this.showSaveIndicator("saving");

    this.saveTimeout = setTimeout(() => {
      callback();
    }, 300);
  }

  clearSaveTimeout() {
    if (this.saveTimeout) {
      clearTimeout(this.saveTimeout);
      this.saveTimeout = null;
    }
  }

  // API calls
  async createBlockOnServer(blockData) {
    try {
      const response = await fetch(
        `/api/documents/${this.documentIdValue}/blocks`,
        {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            Authorization: `Token token=${this.getAuthToken()}`,
          },
          body: JSON.stringify({ block: blockData }),
        },
      );

      if (!response.ok) throw new Error("Failed to create block");

      const data = await response.json();
      // Update block ID in DOM
      const lastBlock = this.blocksContainerTarget.lastElementChild;
      if (lastBlock) {
        lastBlock.dataset.blockId = data.id;
      }

      this.showSaveIndicator("saved");
      return data;  // Return the created block data
    } catch (error) {
      console.error("Create block error:", error);
      this.showSaveIndicator("error");
      throw error;  // Re-throw so caller can handle
    }
  }

  async updateBlockOnServer(blockId, updates) {
    console.log("updateBlockOnServer called:", { blockId, updates });
    console.log("Auth token:", this.getAuthToken());

    try {
      const response = await fetch(
        `/api/documents/${this.documentIdValue}/blocks/${blockId}`,
        {
          method: "PATCH",
          headers: {
            "Content-Type": "application/json",
            Authorization: `Token token=${this.getAuthToken()}`,
          },
          body: JSON.stringify({ block: updates }),
        },
      );

      console.log("Update response status:", response.status);
      if (!response.ok) {
        const errorText = await response.text();
        console.error("Update failed:", errorText);
        throw new Error("Failed to update block");
      }

      this.showSaveIndicator("saved");
    } catch (error) {
      console.error("Update block error:", error);
      this.showSaveIndicator("error");
    }
  }

  async deleteBlockOnServer(blockId, blockElement) {
    try {
      const response = await fetch(
        `/api/documents/${this.documentIdValue}/blocks/${blockId}`,
        {
          method: "DELETE",
          headers: {
            Authorization: `Token token=${this.getAuthToken()}`,
          },
        },
      );

      if (!response.ok) throw new Error("Failed to delete block");

      // Remove from DOM
      blockElement.remove();
      this.showSaveIndicator("saved");
    } catch (error) {
      console.error("Delete block error:", error);
      this.showSaveIndicator("error");
    }
  }

  // Save indicator
  showSaveIndicator(state) {
    if (!this.hasSaveIndicatorTarget) return;

    this.saveIndicatorTarget.textContent =
      {
        saving: "Saving...",
        saved: "✓ Saved",
        error: "⚠ Error",
      }[state] || "";

    this.saveIndicatorTarget.className = `save-indicator save-indicator--${state}`;

    if (state === "saved") {
      setTimeout(() => {
        this.saveIndicatorTarget.textContent = "";
      }, 2000);
    }
  }

  // Helpers
  getAuthToken() {
    const token =
      document.querySelector("meta[name='auth-token']")?.content ||
      "development_token";
    console.log("Auth token:", token); // Debug
    return token;
  }

  escapeHtml(text) {
    const div = document.createElement("div");
    div.textContent = text;
    return div.innerHTML;
  }

  triggerImageUpload(event) {
    const input = event.target
      .closest(".image-block")
      .querySelector("input[type=file]");
    input?.click();
  }

  triggerFileUpload(event) {
    const input = event.target
      .closest(".file-block")
      .querySelector("input[type=file]");
    input?.click();
  }

  async uploadImage(event) {
    const file = event.target.files[0];
    if (!file) return;

    const blockElement = event.target.closest(".block-wrapper");
    const blockId = blockElement.dataset.blockId;

    try {
      this.showSaveIndicator("saving");

      const formData = new FormData();
      formData.append("image", file);

      const response = await fetch(
        `/api/documents/${this.documentIdValue}/blocks/${blockId}/upload_image`,
        {
          method: "POST",
          headers: {
            Authorization: `Token token=${this.getAuthToken()}`,
          },
          body: formData,
        },
      );

      if (!response.ok) throw new Error("Upload failed");

      const data = await response.json();

      // Update block content to show uploaded image
      const imageBlock = blockElement.querySelector(".image-block");
      imageBlock.innerHTML = `
        <img src="${data.block.url}" alt="Uploaded image">
        <div class="image-meta">${data.block.filename} (${this.formatFileSize(data.block.size)})</div>
        <input type="file" accept="image/*" data-action="change->document-editor#uploadImage" style="display:none">
        <button type="button" data-action="click->document-editor#triggerImageUpload">Change</button>
      `;

      this.showSaveIndicator("saved");
    } catch (error) {
      console.error("Image upload error:", error);
      this.showSaveIndicator("error");
      alert("Failed to upload image");
    }
  }

  async uploadFile(event) {
    const file = event.target.files[0];
    if (!file) return;

    const blockElement = event.target.closest(".block-wrapper");
    const blockId = blockElement.dataset.blockId;

    try {
      this.showSaveIndicator("saving");

      const formData = new FormData();
      formData.append("file", file);

      const response = await fetch(
        `/api/documents/${this.documentIdValue}/blocks/${blockId}/upload_file`,
        {
          method: "POST",
          headers: {
            Authorization: `Token token=${this.getAuthToken()}`,
          },
          body: formData,
        },
      );

      if (!response.ok) throw new Error("Upload failed");

      const data = await response.json();

      // Update block content to show uploaded file
      const fileBlock = blockElement.querySelector(".file-block");
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
      `;

      this.showSaveIndicator("saved");
    } catch (error) {
      console.error("File upload error:", error);
      this.showSaveIndicator("error");
      alert("Failed to upload file");
    }
  }

  formatFileSize(bytes) {
    if (bytes < 1024) return bytes + " B";
    if (bytes < 1024 * 1024) return (bytes / 1024).toFixed(1) + " KB";
    return (bytes / (1024 * 1024)).toFixed(1) + " MB";
  }

  // ========================================
  // Drag-and-Drop Reordering
  // ========================================

  setupDragAndDrop() {
    console.log("Setting up drag-and-drop");

    // Event delegation on container
    this.blocksContainerTarget.addEventListener(
      "dragstart",
      this.handleDragStart.bind(this),
    );
    this.blocksContainerTarget.addEventListener(
      "dragend",
      this.handleDragEnd.bind(this),
    );
    this.blocksContainerTarget.addEventListener(
      "dragover",
      this.handleDragOver.bind(this),
    );
    this.blocksContainerTarget.addEventListener(
      "drop",
      this.handleDrop.bind(this),
    );
    this.blocksContainerTarget.addEventListener(
      "dragleave",
      this.handleDragLeave.bind(this),
    );
  }
  
  setupPasteHandler() {
    console.log("Setting up paste handler");
    
    this.blocksContainerTarget.addEventListener('paste', (event) => {
      const pastedText = event.clipboardData.getData('text/plain');
      
      // Only process multi-line markdown pastes
      if (pastedText.includes('\n')) {
        const activeElement = document.activeElement;
        const blockWrapper = activeElement?.closest('.block-wrapper');
        
        // Only auto-process if pasting into empty text block
        if (blockWrapper && blockWrapper.dataset.blockType === 'text' && 
            activeElement.innerText.trim() === '') {
          event.preventDefault();
          console.log('📋 Processing markdown paste');
          this.parseAndCreateBlocks(pastedText, blockWrapper);
        }
      }
    });
  }
  
  parseAndCreateBlocks(text, currentBlock) {
    const lines = text.split('\n');
    const blocks = [];
    let currentTextLines = [];
    
    for (const line of lines) {
      const trimmedLine = line.trim();
      
      // Skip empty lines (use them as paragraph breaks)
      if (trimmedLine === '') {
        if (currentTextLines.length > 0) {
          blocks.push({ type: 'text', text: currentTextLines.join('\n') });
          currentTextLines = [];
        }
        continue;
      }
      
      // Check for markdown patterns
      const markdownMatch = this.detectMarkdownPattern(trimmedLine);
      
      if (markdownMatch) {
        // Save accumulated text as text block
        if (currentTextLines.length > 0) {
          blocks.push({ type: 'text', text: currentTextLines.join('\n') });
          currentTextLines = [];
        }
        // Add markdown block
        blocks.push(markdownMatch);
      } else {
        // Accumulate regular text
        currentTextLines.push(line);
      }
    }
    
    // Add remaining text
    if (currentTextLines.length > 0) {
      blocks.push({ type: 'text', text: currentTextLines.join('\n') });
    }
    
    console.log('📋 Parsed blocks:', blocks);
    
    // Simple approach: Create all blocks as new after current position
    // This avoids reload and race conditions
    if (blocks.length > 0) {
      const currentPosition = parseInt(currentBlock.dataset.position);
      
      // Create all blocks sequentially
      this.createBlocksSequentially(blocks, currentPosition).then(() => {
        // After all blocks created, delete the empty current block if it's saved
        const currentBlockId = currentBlock.dataset.blockId;
        if (currentBlockId && currentBlockId !== 'null') {
          this.deleteBlockOnServer(currentBlockId, currentBlock);
        } else {
          // Just remove from DOM
          currentBlock.remove();
        }
      });
    }
  }
  
  // Helper to create blocks one by one (avoid race conditions)
  async createBlocksSequentially(blocks, afterPosition) {
    for (let i = 0; i < blocks.length; i++) {
      const block = blocks[i];
      try {
        await this.createNewBlockAfter(afterPosition + i, block.type, block, '');
        console.log(`✅ Created block ${i+1}/${blocks.length}`);
      } catch (error) {
        console.error(`❌ Failed to create block ${i+1}:`, error);
        break; // Stop on first error
      }
    }
  }

  handleDragStart(event) {
    // Only handle drag from drag handle
    if (!event.target.classList.contains("block-drag-handle")) {
      return;
    }

    const blockWrapper = event.target.closest(".block-wrapper");
    if (!blockWrapper) return;

    this.draggedBlock = blockWrapper;
    blockWrapper.classList.add("dragging");

    // Set drag data
    event.dataTransfer.effectAllowed = "move";
    event.dataTransfer.setData("text/plain", blockWrapper.dataset.blockId);

    console.log("Drag started:", {
      blockId: blockWrapper.dataset.blockId,
      blockType: blockWrapper.dataset.blockType,
      position: blockWrapper.dataset.position,
    });
  }

  handleDragEnd(event) {
    if (!this.draggedBlock) return;

    this.draggedBlock.classList.remove("dragging");

    // Clean up all drop zones
    this.blocksContainerTarget
      .querySelectorAll(".drop-zone")
      .forEach((zone) => {
        zone.classList.remove("active");
      });

    console.log("Drag ended");
    this.draggedBlock = null;
  }

  handleDragOver(event) {
    event.preventDefault(); // Allow drop

    if (!this.draggedBlock) return;

    const blockWrapper = event.target.closest(".block-wrapper");

    // Don't allow dropping on itself
    if (blockWrapper === this.draggedBlock) {
      event.dataTransfer.dropEffect = "none";
      return;
    }

    event.dataTransfer.dropEffect = "move";

    // Show visual feedback
    if (blockWrapper) {
      const rect = blockWrapper.getBoundingClientRect();
      const midpoint = rect.top + rect.height / 2;

      // Determine if we're in the top or bottom half
      if (event.clientY < midpoint) {
        blockWrapper.classList.add("drop-above");
        blockWrapper.classList.remove("drop-below");
      } else {
        blockWrapper.classList.add("drop-below");
        blockWrapper.classList.remove("drop-above");
      }
    }
  }

  handleDragLeave(event) {
    const blockWrapper = event.target.closest(".block-wrapper");
    if (blockWrapper) {
      blockWrapper.classList.remove("drop-above", "drop-below");
    }
  }

  handleDrop(event) {
    event.preventDefault();
    event.stopPropagation();

    if (!this.draggedBlock) return;

    const targetBlock = event.target.closest(".block-wrapper");

    if (!targetBlock || targetBlock === this.draggedBlock) {
      return;
    }

    const rect = targetBlock.getBoundingClientRect();
    const midpoint = rect.top + rect.height / 2;
    const dropBefore = event.clientY < midpoint;

    console.log("Drop:", {
      draggedId: this.draggedBlock.dataset.blockId,
      targetId: targetBlock.dataset.blockId,
      dropBefore: dropBefore,
    });

    // Clean up visual feedback
    targetBlock.classList.remove("drop-above", "drop-below");

    // Optimistic UI update - move in DOM immediately
    if (dropBefore) {
      targetBlock.before(this.draggedBlock);
    } else {
      targetBlock.after(this.draggedBlock);
    }

    // Get new order of all blocks
    const allBlocks = Array.from(
      this.blocksContainerTarget.querySelectorAll(".block-wrapper"),
    );
    const blockIds = allBlocks
      .map((block) => block.dataset.blockId)
      .filter((id) => id && id !== "null");

    console.log("New block order:", blockIds);

    // Update via API
    this.reorderBlocks(blockIds);
  }

  async reorderBlocks(blockIds) {
    console.log("Reordering blocks via API:", blockIds);
    console.log("Auth token:", this.getAuthToken());

    try {
      const url = `/api/documents/${this.documentIdValue}/blocks/reorder`;
      console.log("Reorder URL:", url);

      const response = await fetch(url, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Authorization: `Token token=${this.getAuthToken()}`,
        },
        body: JSON.stringify({ block_ids: blockIds }),
      });

      console.log("Reorder response status:", response.status);

      if (!response.ok) {
        const errorText = await response.text();
        console.error("Reorder failed:", errorText);
        throw new Error("Failed to reorder blocks");
      }

      const data = await response.json();
      console.log("Reorder response:", data);

      // Update all block positions from server response
      if (data.blocks) {
        this.updateBlockPositions(data.blocks);
      }

      this.showSaveIndicator("saved");
    } catch (error) {
      console.error("Reorder error:", error);
      this.showSaveIndicator("error");
      alert("Failed to reorder blocks. Please refresh the page.");
    }
  }

  updateBlockPositions(blocks) {
    console.log("Updating block positions:", blocks);

    blocks.forEach(({ id, position }) => {
      const wrapper = this.blocksContainerTarget.querySelector(
        `[data-block-id="${id}"]`,
      );
      if (wrapper) {
        wrapper.dataset.position = position;
      }
    });
  }

  // ========================================
  // New Features: Block Type Creation & Shortcuts
  // ========================================

  // 1. Create block of specific type from toolbar button
  createBlockOfType(event) {
    console.log("createBlockOfType called");
    
    const type = event.currentTarget.dataset.type;
    if (!type) {
      console.error("No block type specified");
      return;
    }

    const content = this.getDefaultContentForType(type);
    const newBlock = {
      id: null,
      block_type: type,
      content: content,
    };

    console.log("Creating block of type:", type, content);

    // Optimistic UI update
    this.addBlockToDOM(newBlock);

    // Save to server
    this.createBlockOnServer(newBlock).then(() => {
      // Focus the newly created block
      const lastBlock = this.blocksContainerTarget.lastElementChild;
      if (lastBlock) {
        const contentEditable = lastBlock.querySelector("[contenteditable=true]");
        if (contentEditable) {
          contentEditable.focus();
        }
      }
    });
  }

  // 2. Convert markdown shortcuts
  convertMarkdownShortcut(blockWrapper, text) {
    console.log("convertMarkdownShortcut called", text);

    let newType = null;
    let newContent = {};
    let cleanText = text;

    // Todo: - [ ]
    if (text === '- [ ]' || text === '-[ ]') {
      newType = 'todo';
      newContent = { text: '', checked: false };
      cleanText = '';
    }
    // Code block: ```
    else if (text === '```') {
      newType = 'code';
      newContent = { code: '', language: 'javascript' };
      cleanText = '';
    }
    // Quote: >
    else if (text === '>') {
      newType = 'quote';
      newContent = { text: '' };
      cleanText = '';
    }
    // Headings: #, ##, ###
    else if (text.match(/^#{1,3}$/)) {
      newType = 'heading';
      const level = text.length;
      newContent = { text: '', level: level };
      cleanText = '';
    }

    if (newType) {
      const blockId = blockWrapper.dataset.blockId;
      
      if (!blockId || blockId === 'null') {
        // New unsaved block, just update DOM
        blockWrapper.dataset.blockType = newType;
        const blockContent = blockWrapper.querySelector('.block-content');
        blockContent.innerHTML = this.renderBlockByType({ 
          id: null, 
          block_type: newType, 
          content: newContent 
        });
      } else {
        // Saved block, update via API
        this.updateBlockOnServer(blockId, { 
          block_type: newType, 
          content: newContent 
        }).then(() => {
          // Update DOM after successful server update
          blockWrapper.dataset.blockType = newType;
          const blockContent = blockWrapper.querySelector('.block-content');
          blockContent.innerHTML = this.renderBlockByType({ 
            id: blockId, 
            block_type: newType, 
            content: newContent 
          });
          
          // Focus the new block
          const contentEditable = blockWrapper.querySelector("[contenteditable=true]");
          if (contentEditable) {
            contentEditable.focus();
          }
        });
      }
    }
  }

  // Helper to detect markdown shortcuts
  isMarkdownShortcut(text) {
    const patterns = [
      /^- \[ \]$/,  // Todo
      /^-\[ \]$/,   // Todo (no space)
      /^```$/,      // Code block
      /^>$/,        // Quote
      /^#{1,3}$/,   // Headings (H1-H3)
    ];
    
    return patterns.some(pattern => pattern.test(text));
  }

  // 3. Handle slash commands
  handleSlashCommand(element) {
    console.log("handleSlashCommand called");

    const text = element.innerText || '';
    const lastSlashIndex = text.lastIndexOf('/');
    
    if (lastSlashIndex === -1) return;

    const searchTerm = text.substring(lastSlashIndex + 1).toLowerCase();
    
    const commands = [
      { label: 'Text', type: 'text', keywords: ['text', 'paragraph', 'p'] },
      { label: 'To-do', type: 'todo', keywords: ['todo', 'task', 'checkbox', 'check'] },
      { label: 'Code', type: 'code', keywords: ['code', 'snippet', 'pre'] },
      { label: 'Quote', type: 'quote', keywords: ['quote', 'blockquote', 'q'] },
      { label: 'Heading 1', type: 'heading', keywords: ['h1', 'heading1', 'title'], level: 1 },
      { label: 'Heading 2', type: 'heading', keywords: ['h2', 'heading2', 'subtitle'], level: 2 },
      { label: 'Heading 3', type: 'heading', keywords: ['h3', 'heading3'], level: 3 },
      { label: 'Link', type: 'link', keywords: ['link', 'url', 'href'] },
      { label: 'File', type: 'file', keywords: ['file', 'attachment', 'attach'] },
      { label: 'Image', type: 'image', keywords: ['image', 'img', 'picture', 'photo'] },
    ];

    // Filter commands based on search term
    const filteredCommands = commands.filter(cmd => 
      cmd.keywords.some(keyword => keyword.includes(searchTerm))
    );

    if (filteredCommands.length === 0) return;

    // Create and show menu
    this.showSlashMenu(element, filteredCommands, lastSlashIndex);
  }

  showSlashMenu(element, commands, slashIndex) {
    // Remove existing menu if any
    const existingMenu = document.querySelector('.slash-menu');
    if (existingMenu) {
      existingMenu.remove();
    }

    // Create menu
    const menu = document.createElement('div');
    menu.className = 'slash-menu';
    menu.style.position = 'absolute';
    menu.style.zIndex = '1000';
    menu.style.backgroundColor = 'white';
    menu.style.border = '1px solid #ccc';
    menu.style.borderRadius = '4px';
    menu.style.boxShadow = '0 2px 10px rgba(0,0,0,0.1)';
    menu.style.minWidth = '200px';
    menu.style.maxHeight = '300px';
    menu.style.overflowY = 'auto';

    commands.forEach((cmd, index) => {
      const item = document.createElement('div');
      item.className = 'slash-menu-item';
      item.textContent = cmd.label;
      item.style.padding = '8px 12px';
      item.style.cursor = 'pointer';
      item.style.borderBottom = index < commands.length - 1 ? '1px solid #eee' : 'none';
      
      item.addEventListener('mouseenter', () => {
        item.style.backgroundColor = '#f5f5f5';
      });
      
      item.addEventListener('mouseleave', () => {
        item.style.backgroundColor = 'white';
      });

      item.addEventListener('click', () => {
        this.selectSlashCommand(element, cmd, slashIndex);
        menu.remove();
      });

      menu.appendChild(item);
    });

    // Position menu near cursor
    const rect = element.getBoundingClientRect();
    menu.style.left = `${rect.left}px`;
    menu.style.top = `${rect.bottom + 5}px`;

    document.body.appendChild(menu);

    // Close menu on click outside or escape
    const closeMenu = (event) => {
      if (event.type === 'click' && !menu.contains(event.target)) {
        menu.remove();
        document.removeEventListener('click', closeMenu);
        document.removeEventListener('keydown', closeMenu);
      } else if (event.type === 'keydown' && event.key === 'Escape') {
        menu.remove();
        document.removeEventListener('click', closeMenu);
        document.removeEventListener('keydown', closeMenu);
      }
    };

    setTimeout(() => {
      document.addEventListener('click', closeMenu);
      document.addEventListener('keydown', closeMenu);
    }, 100);
  }

  selectSlashCommand(element, command, slashIndex) {
    console.log("selectSlashCommand called", command);

    const blockWrapper = element.closest(".block-wrapper");
    if (!blockWrapper) return;

    // Remove the slash command text
    const text = element.innerText || '';
    const beforeSlash = text.substring(0, slashIndex);
    
    // Determine content based on command
    let content = this.getDefaultContentForType(command.type);
    
    // For headings with specific level
    if (command.type === 'heading' && command.level) {
      content.level = command.level;
    }
    
    // Preserve any text before the slash command
    if (beforeSlash.trim()) {
      if (command.type === 'text') {
        content.text = beforeSlash.trim();
      } else if (command.type === 'heading' || command.type === 'quote' || command.type === 'todo') {
        content.text = beforeSlash.trim();
      } else if (command.type === 'code') {
        content.code = beforeSlash.trim();
      }
    }

    const blockId = blockWrapper.dataset.blockId;

    if (!blockId || blockId === 'null') {
      // New unsaved block
      blockWrapper.dataset.blockType = command.type;
      const blockContent = blockWrapper.querySelector('.block-content');
      blockContent.innerHTML = this.renderBlockByType({ 
        id: null, 
        block_type: command.type, 
        content: content 
      });
    } else {
      // Update existing block
      this.updateBlockOnServer(blockId, { 
        block_type: command.type, 
        content: content 
      }).then(() => {
        blockWrapper.dataset.blockType = command.type;
        const blockContent = blockWrapper.querySelector('.block-content');
        blockContent.innerHTML = this.renderBlockByType({ 
          id: blockId, 
          block_type: command.type, 
          content: content 
        });
        
        const contentEditable = blockWrapper.querySelector("[contenteditable=true]");
        if (contentEditable) {
          contentEditable.focus();
        }
      });
    }
  }

  // 4. Get default content for each block type
  getDefaultContentForType(type) {
    const defaults = {
      text: { text: '' },
      heading: { text: '', level: 2 },
      todo: { text: '', checked: false },
      code: { code: '', language: 'javascript' },
      quote: { text: '' },
      link: { url: '', title: '' },
      file: {},
      image: {}
    };

    return defaults[type] || { text: '' };
  }
}
