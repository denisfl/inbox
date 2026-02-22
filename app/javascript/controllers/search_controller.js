import { Controller } from "@hotwired/stimulus";

// Connects to data-controller="search"
export default class extends Controller {
  static targets = ["input", "results", "loading", "count", "time", "popup"];
  static values = {
    url: String,
  };

  connect() {
    console.log("Search controller connected");
    this.searchTimeout = null;
    this.isPopupOpen = false;
    
    // Close popup when clicking outside
    document.addEventListener('click', this.handleClickOutside.bind(this));
  }

  disconnect() {
    this.clearSearchTimeout();
    document.removeEventListener('click', this.handleClickOutside.bind(this));
  }

  toggleSearch(event) {
    event.stopPropagation();
    this.isPopupOpen = !this.isPopupOpen;
    
    if (this.hasPopupTarget) {
      this.popupTarget.style.display = this.isPopupOpen ? 'block' : 'none';
      
      if (this.isPopupOpen && this.hasInputTarget) {
        setTimeout(() => this.inputTarget.focus(), 100);
      }
    }
  }

  handleClickOutside(event) {
    if (this.hasPopupTarget && this.isPopupOpen && !this.element.contains(event.target)) {
      this.isPopupOpen = false;
      this.popupTarget.style.display = 'none';
    }
  }

  handleKeyup(event) {
    if (event.key === 'Enter') {
      const query = this.inputTarget.value.trim();
      if (query.length > 0) {
        // Redirect to documents index with query parameter
        window.location.href = `/?q=${encodeURIComponent(query)}`;
      }
    } else if (event.key === 'Escape') {
      this.isPopupOpen = false;
      this.popupTarget.style.display = 'none';
    }
  }

  search(event) {
    const query = this.inputTarget.value.trim();

    if (query.length === 0) {
      this.resultsTarget.innerHTML = "";
      this.countTarget.textContent = "";
      this.timeTarget.textContent = "";
      return;
    }

    // Debounce search (wait 300ms after user stops typing)
    this.clearSearchTimeout();
    this.searchTimeout = setTimeout(() => {
      this.performSearch(query);
    }, 300);
  }

  async performSearch(query) {
    console.log("Searching for:", query);

    this.showLoading();

    try {
      const url = `${this.urlValue}?q=${encodeURIComponent(query)}`;
      console.log("Search URL:", url);

      const response = await fetch(url, {
        headers: {
          Authorization: `Token token=${this.getAuthToken()}`,
        },
      });

      if (!response.ok) {
        throw new Error(`Search failed: ${response.status}`);
      }

      const data = await response.json();
      console.log("Search results:", data);

      this.displayResults(data);
    } catch (error) {
      console.error("Search error:", error);
      this.displayError(error.message);
    } finally {
      this.hideLoading();
    }
  }

  displayResults(data) {
    const { results, meta } = data;

    // Update count and time
    this.countTarget.textContent = `Found ${meta.total} result${meta.total !== 1 ? "s" : ""}`;
    this.timeTarget.textContent = `(${meta.search_time_ms}ms)`;

    if (results.length === 0) {
      this.resultsTarget.innerHTML = `
        <div class="empty-state">
          <p>No documents found for "${meta.query}"</p>
        </div>
      `;
      return;
    }

    // Render results
    this.resultsTarget.innerHTML = results
      .map((result) => this.renderResult(result))
      .join("");
  }

  renderResult(result) {
    return `
      <div class="search-result">
        <h3 class="result-title">
          <a href="/documents/${result.id}/edit">${result.title_snippet}</a>
        </h3>
        <div class="result-meta">
          <span class="result-source">${result.source}</span>
          <span class="result-date">${this.formatDate(result.created_at)}</span>
          <span class="result-blocks">${result.blocks_count} block${result.blocks_count !== 1 ? "s" : ""}</span>
        </div>
        <p class="result-snippet">${result.content_snippet}</p>
      </div>
    `;
  }

  displayError(message) {
    this.resultsTarget.innerHTML = `
      <div class="error-state">
        <p>Error: ${message}</p>
      </div>
    `;
  }

  showLoading() {
    if (this.hasLoadingTarget) {
      this.loadingTarget.classList.remove("hidden");
    }
  }

  hideLoading() {
    if (this.hasLoadingTarget) {
      this.loadingTarget.classList.add("hidden");
    }
  }

  clearSearchTimeout() {
    if (this.searchTimeout) {
      clearTimeout(this.searchTimeout);
      this.searchTimeout = null;
    }
  }

  getAuthToken() {
    return (
      document.querySelector('meta[name="auth-token"]')?.content ||
      localStorage.getItem("auth_token") ||
      "your_random_secure_token_here"
    );
  }

  formatDate(dateString) {
    const date = new Date(dateString);
    const now = new Date();
    const diffDays = Math.floor((now - date) / (1000 * 60 * 60 * 24));

    if (diffDays === 0) return "Today";
    if (diffDays === 1) return "Yesterday";
    if (diffDays < 7) return `${diffDays} days ago`;
    if (diffDays < 30) return `${Math.floor(diffDays / 7)} weeks ago`;
    if (diffDays < 365) return `${Math.floor(diffDays / 30)} months ago`;
    return date.toLocaleDateString();
  }
}
