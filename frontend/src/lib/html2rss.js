// HTML2RSS integration for Astro API endpoints
import { spawn } from "child_process"
import { readFileSync } from "fs"
import { join } from "path"

// Load Ruby dependencies
const RUBY_PATH = process.env.RUBY_PATH || "ruby"
const APP_ROOT = process.env.APP_ROOT || join(process.cwd(), "..")

/**
 * Execute Ruby code and return the result
 * @param {string} rubyCode - Ruby code to execute
 * @returns {Promise<string>} - Result of Ruby execution
 */
async function executeRuby(rubyCode) {
  return new Promise((resolve, reject) => {
    const ruby = spawn("bundle", ["exec", "ruby", "-e", rubyCode], {
      cwd: APP_ROOT,
      stdio: ["pipe", "pipe", "pipe"],
      env: { ...process.env, BUNDLE_GEMFILE: join(APP_ROOT, "Gemfile") },
    })

    let stdout = ""
    let stderr = ""

    ruby.stdout.on("data", (data) => {
      stdout += data.toString()
    })

    ruby.stderr.on("data", (data) => {
      stderr += data.toString()
    })

    ruby.on("close", (code) => {
      if (code === 0) {
        resolve(stdout)
      } else {
        reject(new Error(`Ruby execution failed: ${stderr}`))
      }
    })
  })
}

/**
 * Generate RSS feed using html2rss
 * @param {Object} config - Feed configuration
 * @param {Object} params - URL parameters
 * @returns {Promise<string>} - RSS XML content
 */
export async function generateFeed(config, params = {}) {
  const rubyCode = `
    require 'bundler/setup'
    require 'html2rss'
    require_relative 'app/ssrf_filter_strategy'
    require_relative 'app/local_config'

    # Set up html2rss
    Html2rss::RequestService.register_strategy(:ssrf_filter, Html2rss::Web::SsrfFilterStrategy)
    Html2rss::RequestService.default_strategy_name = :ssrf_filter
    Html2rss::RequestService.unregister_strategy(:faraday)

    # Merge parameters into config
    config = ${JSON.stringify(config)}
    config[:params] ||= {}
    config[:params].merge!(${JSON.stringify(params)})

    # Set default strategy
    config[:strategy] ||= :ssrf_filter

    # Generate feed
    feed = Html2rss.feed(config)
    puts feed.to_s
  `

  try {
    return await executeRuby(rubyCode)
  } catch (error) {
    throw new Error(`Failed to generate feed: ${error.message}`)
  }
}

/**
 * Load local config by name
 * @param {string} name - Config name
 * @returns {Promise<Object>} - Config object
 */
export async function loadLocalConfig(name) {
  const rubyCode = `
    require 'bundler/setup'
    require 'json'
    require_relative 'app/local_config'

    config = Html2rss::Web::LocalConfig.find('${name}')
    puts JSON.generate(config)
  `

  try {
    const result = await executeRuby(rubyCode)
    return JSON.parse(result)
  } catch (error) {
    throw new Error(`Config not found: ${name}`)
  }
}

/**
 * Get all available feed names
 * @returns {Promise<Array<string>>} - Array of feed names
 */
export async function getFeedNames() {
  const rubyCode = `
    require 'bundler/setup'
    require 'json'
    require_relative 'app/local_config'

    names = Html2rss::Web::LocalConfig.feed_names
    puts JSON.generate(names)
  `

  try {
    const result = await executeRuby(rubyCode)
    return JSON.parse(result)
  } catch (error) {
    return []
  }
}

/**
 * Run health check
 * @returns {Promise<string>} - Health check result
 */
export async function runHealthCheck() {
  const rubyCode = `
    require 'bundler/setup'
    require_relative 'app/health_check'

    result = Html2rss::Web::HealthCheck.run
    puts result
  `

  try {
    return await executeRuby(rubyCode)
  } catch (error) {
    return `Health check failed: ${error.message}`
  }
}
