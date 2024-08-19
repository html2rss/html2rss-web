class FormHandler {
  constructor() {
    // Initialize DOM elements
    this.form = document.querySelector("form");
    this.urlInput = document.querySelector("#url");
    this.iframe = document.querySelector("iframe");
    this.rssUrlInput = document.querySelector("#rss_url");

    if (!this.form || !this.urlInput || !this.iframe || !this.rssUrlInput) {
      console.error(
        "One or more necessary form elements were not found in the DOM.",
      );
      return;
    }

    // Bind event handlers
    this.initEventListeners();
    this.setInitialUrl();
  }

  /**
   * Initializes event listeners for form elements.
   */
  initEventListeners() {
    // Event listener for URL input change
    this.urlInput.addEventListener("change", () => this.clearRssUrl());

    // Event listener for form submit
    this.form.addEventListener("submit", (event) =>
      this.handleFormSubmit(event),
    );

    // Event listener for RSS URL input focus
    this.rssUrlInput.addEventListener("focus", () => {
      const strippedIframeSrc = this.iframe.src.replace("#items", "").trim();
      if (this.rssUrlInput.value.trim() !== strippedIframeSrc) {
        this.updateIframeSrc(this.rssUrlInput.value.trim());
      }
    });
  }

  /**
   * Sets the initial URL from query parameter if it exists.
   */
  setInitialUrl() {
    const params = new URLSearchParams(window.location.search);
    const initialUrl = params.get("url");
    if (initialUrl) {
      this.urlInput.value = initialUrl;
      this.form.dispatchEvent(new Event("submit"));
    }
  }

  /**
   * Clears the RSS URL input value.
   */
  clearRssUrl() {
    this.rssUrlInput.value = "";
  }

  /**
   * Handles form submission.
   * @param {Event} event - The form submit event.
   */
  handleFormSubmit(event) {
    event.preventDefault();
    const url = this.urlInput.value;

    if (this.isValidUrl(url)) {
      const encodedUrl = this.encodeUrl(url);
      const autoSourceUrl = this.generateAutoSourceUrl(encodedUrl);

      this.rssUrlInput.value = autoSourceUrl;
      this.rssUrlInput.select();

      if (window.location.search !== `?url=${url}`) {
        window.history.pushState({}, "", `?url=${url}`);
      }
    }
  }

  /**
   * Checks if the URL is valid and starts with "http".
   * @param {string} url - The URL to validate.
   * @returns {boolean} True if the URL is valid, false otherwise.
   */
  isValidUrl(url) {
    try {
      new URL(url);
      return url.trim() !== "" && url.startsWith("http");
    } catch (_) {
      return false;
    }
  }

  /**
   * Encodes the URL using base64 encoding.
   * @param {string} url - The URL to encode.
   * @returns {string} The base64 encoded URL.
   */
  encodeUrl(url) {
    return btoa(url).replace(/=/g, "");
  }

  /**
   * Generates an auto-source URL.
   * @param {string} encodedUrl - The base64 encoded URL.
   * @returns {string} The generated auto-source URL.
   */
  generateAutoSourceUrl(encodedUrl) {
    const BASE_URL = "auto_source"; // Use constant to avoid magic strings
    const baseUrl = new URL(window.location.origin);
    return `${baseUrl}${BASE_URL}/${encodedUrl}`;
  }

  /**
   * Updates the iframe source.
   * @param {string} rssUrlValue - The RSS URL value.
   */
  updateIframeSrc(rssUrlValue) {
    this.iframe.src = rssUrlValue === "" ? "" : `${rssUrlValue}#items`;
  }
}

// Initialize FormHandler when the document is ready
if (document.readyState === "complete") {
  new FormHandler();
} else {
  document.addEventListener("DOMContentLoaded", () => new FormHandler());
}
