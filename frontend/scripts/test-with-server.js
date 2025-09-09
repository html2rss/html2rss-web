#!/usr/bin/env node

// Test script that starts Ruby server, runs tests, then stops server
const { spawn } = require("child_process")
const { promisify } = require("util")
const exec = promisify(require("child_process").exec)
const path = require("path")

const RUBY_SERVER_PORT = 3000
const ASTRO_SERVER_PORT = 4321
const MAX_WAIT_TIME = 30000 // 30 seconds

let rubyServer = null
let astroServer = null

async function waitForServer(url, maxWait = MAX_WAIT_TIME) {
  const startTime = Date.now()

  while (Date.now() - startTime < maxWait) {
    try {
      const response = await fetch(url, {
        method: "GET",
        signal: AbortSignal.timeout(1000),
      })

      if (response.ok) {
        return true
      }
    } catch (error) {
      // Server not ready yet
    }

    await new Promise((resolve) => setTimeout(resolve, 500))
  }

  return false
}

async function startRubyServer() {
  console.log("🚀 Starting Ruby server...")

  return new Promise((resolve, reject) => {
    rubyServer = spawn("bundle", ["exec", "puma", "-p", RUBY_SERVER_PORT.toString()], {
      cwd: path.join(__dirname, "..", ".."),
      stdio: "pipe",
      env: {
        ...process.env,
        RACK_ENV: "development",
        AUTO_SOURCE_ENABLED: "true",
        AUTO_SOURCE_USERNAME: "admin",
        AUTO_SOURCE_PASSWORD: "changeme",
        AUTO_SOURCE_ALLOWED_ORIGINS: "localhost:3000",
        AUTO_SOURCE_ALLOWED_URLS: "https://github.com/*,https://example.com/*",
      },
    })

    rubyServer.stdout.on("data", (data) => {
      const output = data.toString()
      if (output.includes("Listening on")) {
        console.log("✅ Ruby server started")
        resolve()
      }
    })

    rubyServer.stderr.on("data", (data) => {
      const error = data.toString()
      if (error.includes("Address already in use")) {
        console.log("⚠️  Ruby server already running on port 3000")
        resolve()
      } else if (error.includes("ERROR")) {
        console.error("❌ Ruby server error:", error)
        reject(new Error(error))
      }
    })

    rubyServer.on("error", (error) => {
      console.error("❌ Failed to start Ruby server:", error)
      reject(error)
    })

    // Timeout after 30 seconds
    setTimeout(() => {
      reject(new Error("Ruby server startup timeout"))
    }, MAX_WAIT_TIME)
  })
}

async function startAstroServer() {
  console.log("🚀 Starting Astro server...")

  return new Promise((resolve, reject) => {
    astroServer = spawn("npm", ["run", "dev"], {
      cwd: __dirname,
      stdio: "pipe",
      env: {
        ...process.env,
        AUTO_SOURCE_ENABLED: "true",
        AUTO_SOURCE_USERNAME: "admin",
        AUTO_SOURCE_PASSWORD: "changeme",
        AUTO_SOURCE_ALLOWED_ORIGINS: "localhost:3000,localhost:4321",
        AUTO_SOURCE_ALLOWED_URLS: "https://github.com/*,https://example.com/*",
      },
    })

    astroServer.stdout.on("data", (data) => {
      const output = data.toString()
      if (output.includes("Local:") && output.includes("4321")) {
        console.log("✅ Astro server started")
        resolve()
      }
    })

    astroServer.stderr.on("data", (data) => {
      const error = data.toString()
      if (error.includes("EADDRINUSE")) {
        console.log("⚠️  Astro server already running on port 4321")
        resolve()
      } else if (error.includes("ERROR")) {
        console.error("❌ Astro server error:", error)
        reject(new Error(error))
      }
    })

    astroServer.on("error", (error) => {
      console.error("❌ Failed to start Astro server:", error)
      reject(error)
    })

    // Timeout after 30 seconds
    setTimeout(() => {
      reject(new Error("Astro server startup timeout"))
    }, MAX_WAIT_TIME)
  })
}

async function stopServers() {
  console.log("🛑 Stopping servers...")

  const stopPromises = []

  if (rubyServer) {
    stopPromises.push(
      new Promise((resolve) => {
        rubyServer.kill("SIGTERM")
        rubyServer.on("exit", () => {
          console.log("✅ Ruby server stopped")
          resolve()
        })

        // Force kill after 5 seconds
        setTimeout(() => {
          rubyServer.kill("SIGKILL")
          resolve()
        }, 5000)
      }),
    )
  }

  if (astroServer) {
    stopPromises.push(
      new Promise((resolve) => {
        astroServer.kill("SIGTERM")
        astroServer.on("exit", () => {
          console.log("✅ Astro server stopped")
          resolve()
        })

        // Force kill after 5 seconds
        setTimeout(() => {
          astroServer.kill("SIGKILL")
          resolve()
        }, 5000)
      }),
    )
  }

  await Promise.all(stopPromises)
}

async function runTests() {
  console.log("🧪 Running tests...")

  try {
    const { stdout, stderr } = await exec("npm test -- --run", {
      cwd: __dirname,
      env: {
        ...process.env,
        AUTO_SOURCE_ENABLED: "true",
        AUTO_SOURCE_USERNAME: "admin",
        AUTO_SOURCE_PASSWORD: "changeme",
        AUTO_SOURCE_ALLOWED_ORIGINS: "localhost:3000,localhost:4321",
        AUTO_SOURCE_ALLOWED_URLS: "https://github.com/*,https://example.com/*",
      },
    })

    console.log(stdout)
    if (stderr) {
      console.error(stderr)
    }

    return true
  } catch (error) {
    console.error("❌ Tests failed:", error.message)
    return false
  }
}

async function main() {
  let success = false

  try {
    // Start servers
    await startRubyServer()
    await startAstroServer()

    // Wait for servers to be ready
    console.log("⏳ Waiting for servers to be ready...")
    const rubyReady = await waitForServer(`http://localhost:${RUBY_SERVER_PORT}/health_check.txt`)
    const astroReady = await waitForServer(`http://localhost:${ASTRO_SERVER_PORT}/api/feeds.json`)

    if (!rubyReady && !astroReady) {
      throw new Error("No servers are ready")
    }

    if (rubyReady) {
      console.log("✅ Ruby server is ready")
    }
    if (astroReady) {
      console.log("✅ Astro server is ready")
    }

    // Run tests
    success = await runTests()
  } catch (error) {
    console.error("❌ Test setup failed:", error.message)
    process.exitCode = 1
  } finally {
    // Always stop servers
    await stopServers()
  }

  if (success) {
    console.log("✅ All tests passed!")
  } else {
    console.log("❌ Some tests failed")
    process.exitCode = 1
  }
}

// Handle process termination
process.on("SIGINT", async () => {
  console.log("\n🛑 Received SIGINT, stopping servers...")
  await stopServers()
  process.exit(1)
})

process.on("SIGTERM", async () => {
  console.log("\n🛑 Received SIGTERM, stopping servers...")
  await stopServers()
  process.exit(1)
})

main().catch(console.error)
