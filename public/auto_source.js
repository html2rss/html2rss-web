const autoSource = (function () {
  const ALLOWED_ORIGINS = ["127.0.0.1", "::1"];

  function assertAllowedOrigin() {
    const allowedOrigin = ALLOWED_ORIGINS.includes(location.host.split(":")[0]);

    if (allowedOrigin) {
      return;
    }

    if (location.protocol !== "https:") {
      throw new Error("You must use HTTPS for the auto_source feature.");
    }
  }

  class Bookmarklet {
    constructor() {
      const $bookmarklet = document.querySelector("a#bookmarklet");

      if (!$bookmarklet) {
        console.error("Bookmarklet element not found in the DOM.");
        return;
      }

      $bookmarklet.href = this.generateBookmarkletHref();
    }

    generateBookmarkletHref() {
      const h2rUrl = new URL(window.location.origin);
      h2rUrl.pathname = "auto_source/";
      h2rUrl.search = `?url=`;
      h2rUrl.hash = "";

      return `javascript:window.location.href='${h2rUrl.toString()}'+window.location.href;`;
    }
  }

  class FormHandler {
    constructor() {
      // Initialize DOM elements
      this.form = document.querySelector("form");
      this.urlInput = document.querySelector("#url");
      this.iframe = document.querySelector("iframe");
      this.rssUrlInput = document.querySelector("#rss_url");

      if (!this.form || !this.urlInput || !this.iframe || !this.rssUrlInput) {
        console.error("One or more necessary form elements were not found in the DOM.");
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
      this.form.addEventListener("submit", (event) => this.handleFormSubmit(event));

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

      this.rssUrlInput.value = "";
      this.iframe.src = "";

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

  class ButtonHandler {
    constructor() {
      // Cache necessary DOM elements
      const copyButton = document.querySelector("#copy");
      const gotoButton = document.querySelector("#goto");
      const openInFeedButton = document.querySelector("#openInFeed");
      const rssUrlField = document.querySelector("#rss_url");
      const resetCredentialsButton = document.querySelector("#resetCredentials");

      if (!copyButton || !gotoButton || !openInFeedButton || !rssUrlField || !resetCredentialsButton) {
        console.error("One or more necessary button elements were not found in the DOM.");
        return;
      }

      // Assign elements to instance variables
      this.copyButton = copyButton;
      this.gotoButton = gotoButton;
      this.openInFeedButton = openInFeedButton;
      this.rssUrlField = rssUrlField;
      this.resetCredentialsButton = resetCredentialsButton;

      // Initialize event listeners
      this.initEventListeners();
    }

    /**
     * Initializes event listeners for buttons.
     */
    initEventListeners() {
      // Bind event handlers to the context of the class instance
      this.copyButton.addEventListener("click", this.copyText.bind(this));
      this.gotoButton.addEventListener("click", this.openLink.bind(this));
      this.openInFeedButton.addEventListener("click", this.subscribeToFeed.bind(this));
      this.resetCredentialsButton.addEventListener("click", this.resetCredentials.bind(this));
    }

    /**
     * Copies the text from the text field to the clipboard.
     */
    async copyText() {
      try {
        const textToCopy = this.rssUrlField.value;
        await navigator.clipboard.writeText(textToCopy);
        console.log("Text copied to clipboard:", textToCopy);
      } catch (error) {
        console.error("Failed to copy text to clipboard:", error);
      }
    }

    /**
     * Opens the link specified in the text field.
     */
    openLink() {
      const linkToOpen = this.rssUrlField?.value;

      if (typeof linkToOpen === "string" && linkToOpen.trim() !== "") {
        window.open(linkToOpen, "_blank", "noopener,noreferrer");
      }
    }

    /**
     * Subscribes to the feed specified in the text field.
     */
    async subscribeToFeed() {
      assertAllowedOrigin();

      const feedUrl = this.rssUrlField.value;
      const storedUser = LocalStorageFacade.getOrAskUser("username");
      const storedPassword = LocalStorageFacade.getOrAskUser("password");

      const url = new URL(feedUrl);
      url.username = storedUser;
      url.password = storedPassword;

      const feedUrlWithAuth = `feed:${url.toString()}`;

      window.open(feedUrlWithAuth);
    }

    resetCredentials() {
      ["username", "password"].forEach((key) => {
        LocalStorageFacade.remove(key);
      });

      alert("Credentials have been reset. Click 'Subscribe' to re-enter credentials.");
    }
  }

  class LocalStorageFacade {
    static get prefix() {
      return "html2rss-web/auto_source/";
    }

    static get(key) {
      key = LocalStorageFacade.encode(`${LocalStorageFacade.prefix}${key}`);

      return LocalStorageFacade.decode(localStorage.getItem(key));
    }

    static set(key, value) {
      key = LocalStorageFacade.encode(`${LocalStorageFacade.prefix}${key}`);

      return localStorage.setItem(key, LocalStorageFacade.encode(value));
    }

    static remove(key) {
      key = LocalStorageFacade.encode(`${LocalStorageFacade.prefix}${key}`);

      return localStorage.removeItem(key);
    }

    static getOrAskUser(columnName) {
      let value = LocalStorageFacade.get(columnName);

      while (typeof value !== "string" || value === "") {
        value = window.prompt(`Please enter your ${columnName}:`);

        if (!value || value.trim() === "") {
          alert(`Blank ${columnName} submitted. Try again!`);
        } else {
          LocalStorageFacade.set(columnName, value);
        }
      }

      return value;
    }

    static encode(value) {
      return btoa(value.trim()).replace(/=/g, "");
    }

    static decode(value) {
      if (typeof value !== "string") {
        return null;
      }

      return atob(value);
    }
  }

  function init() {
    new Bookmarklet();
    new FormHandler();
    new ButtonHandler();
  }

  return { init: init };
})();

document.readyState === "complete"
  ? autoSource.init()
  : document.addEventListener("DOMContentLoaded", autoSource.init());
