#!/usr/bin/env node

import { createHash } from "node:crypto";

const DEFAULT_REPO = "likehao0522cn-gif/auto";
const BUNDLE_ID = "com.shm06.TuneMetronome";
const REQUIRED_ASSETS = ["TuneMetronome.ipa", "source.json", "icon.png"];
const USER_AGENT = "tune-metronome-release-verifier";
const REQUEST_TIMEOUT_MS = 60_000;

function usage() {
  return [
    "usage: node scripts/verify-store-release.mjs TAG [REPO] [options]",
    "",
    "options:",
    "  --wait-seconds N    wait for the release to become Latest (default: 0)",
    "  --allow-not-latest  allow verifying a release that is not Latest",
    "  --help              show this help",
  ].join("\n");
}

function parseArgs(argv) {
  const positional = [];
  let waitSeconds = 0;
  let allowNotLatest = false;

  for (let index = 0; index < argv.length; index += 1) {
    const argument = argv[index];
    if (argument === "--help") {
      process.stdout.write(`${usage()}\n`);
      process.exit(0);
    }
    if (argument === "--allow-not-latest") {
      allowNotLatest = true;
      continue;
    }
    if (argument === "--wait-seconds") {
      const value = argv[index + 1];
      if (value === undefined || !/^\d+$/.test(value)) {
        throw new Error("--wait-seconds requires a non-negative integer");
      }
      waitSeconds = Number(value);
      index += 1;
      continue;
    }
    if (argument.startsWith("-")) {
      throw new Error(`unknown option: ${argument}`);
    }
    positional.push(argument);
  }

  const [tag, repo = DEFAULT_REPO] = positional;
  if (!tag) {
    throw new Error(usage());
  }
  if (!/^v\d+\.\d+\.\d+(?:-[0-9A-Za-z.-]+)?$/.test(tag)) {
    throw new Error(`tag must look like v1.2.3, got: ${tag}`);
  }
  if (!/^[A-Za-z0-9_.-]+\/[A-Za-z0-9_.-]+$/.test(repo)) {
    throw new Error(`repository must look like owner/name, got: ${repo}`);
  }

  return { tag, repo, waitSeconds, allowNotLatest };
}

function versionFromTag(tag) {
  return tag.replace(/^v/, "");
}

function apiHeaders() {
  const headers = {
    Accept: "application/vnd.github+json",
    "User-Agent": USER_AGENT,
  };
  const token = process.env.GH_TOKEN || process.env.GITHUB_TOKEN;
  if (token) {
    headers.Authorization = `Bearer ${token}`;
  }
  return headers;
}

async function fetchResponse(url, { headers = { "User-Agent": USER_AGENT } } = {}) {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), REQUEST_TIMEOUT_MS);
  try {
    return await fetch(url, {
      headers,
      redirect: "follow",
      signal: controller.signal,
    });
  } finally {
    clearTimeout(timer);
  }
}

async function retry(label, operation, attempts = 4) {
  let lastError;
  for (let attempt = 1; attempt <= attempts; attempt += 1) {
    try {
      return await operation();
    } catch (error) {
      lastError = error;
      if (attempt === attempts) {
        break;
      }
      process.stdout.write(`[retry] ${label}: ${error.message}\n`);
      await new Promise((resolve) => setTimeout(resolve, Math.min(8_000, attempt * 1_500)));
    }
  }
  throw new Error(`${label} failed after ${attempts} attempts: ${lastError?.message ?? lastError}`);
}

async function getJson(url, label) {
  return retry(label, async () => {
    const response = await fetchResponse(url, { headers: apiHeaders() });
    if (!response.ok) {
      throw new Error(`${url} returned HTTP ${response.status}`);
    }
    return response.json();
  });
}

async function getBytes(url, label) {
  return retry(label, async () => {
    const response = await fetchResponse(url);
    if (!response.ok) {
      throw new Error(`${url} returned HTTP ${response.status}`);
    }
    return Buffer.from(await response.arrayBuffer());
  });
}

function assertEqual(actual, expected, label) {
  if (actual !== expected) {
    throw new Error(`${label}: expected ${JSON.stringify(expected)}, got ${JSON.stringify(actual)}`);
  }
}

function requireString(value, label) {
  if (typeof value !== "string" || value.length === 0) {
    throw new Error(`${label} must be a non-empty string`);
  }
  return value;
}

async function waitForLatest(repo, tag, waitSeconds, allowNotLatest) {
  const deadline = Date.now() + waitSeconds * 1_000;
  let lastLatest = "";
  for (;;) {
    const latest = await getJson(
      `https://api.github.com/repos/${repo}/releases/latest`,
      "fetch latest release",
    );
    lastLatest = String(latest.tag_name ?? "");
    if (lastLatest === tag) {
      return;
    }
    if (allowNotLatest) {
      return;
    }
    if (Date.now() >= deadline) {
      throw new Error(
        `release ${tag} is not Latest; GitHub currently reports ${lastLatest || "no latest release"}`,
      );
    }
    process.stdout.write(`[wait] release ${tag} is not Latest yet (currently ${lastLatest || "none"})\n`);
    await new Promise((resolve) => setTimeout(resolve, 5_000));
  }
}

function validateReleaseMetadata(release, tag) {
  assertEqual(release.tag_name, tag, "release tag");
  assertEqual(release.draft, false, "release draft state");
  assertEqual(release.prerelease, false, "release prerelease state");
  requireString(release.html_url, "release html_url");

  const assets = new Map();
  for (const asset of release.assets ?? []) {
    requireString(asset.name, "asset name");
    assets.set(asset.name, asset);
  }
  for (const name of REQUIRED_ASSETS) {
    if (!assets.has(name)) {
      throw new Error(`release is missing required asset: ${name}`);
    }
  }

  const names = [...assets.keys()].sort();
  const expectedNames = [...REQUIRED_ASSETS].sort();
  assertEqual(JSON.stringify(names), JSON.stringify(expectedNames), "release asset names");

  for (const name of REQUIRED_ASSETS) {
    const asset = assets.get(name);
    assertEqual(asset.state, "uploaded", `${name} upload state`);
    if (!Number.isInteger(asset.size) || asset.size <= 0) {
      throw new Error(`${name} has an invalid size`);
    }
    requireString(asset.browser_download_url, `${name} download URL`);
    if (name !== "source.json" && !asset.digest?.startsWith("sha256:")) {
      throw new Error(`${name} is missing a sha256 digest`);
    }
  }

  return assets;
}

function validateSource(source, { tag, repo, ipaAsset, iconAsset, sourceAsset }) {
  const version = versionFromTag(tag);
  requireString(source.name, "source.name");
  requireString(source.identifier, "source.identifier");
  assertEqual(source.website, `https://github.com/${repo}`, "source.website");

  if (!Array.isArray(source.apps) || source.apps.length !== 1) {
    throw new Error("source.apps must contain exactly one app");
  }
  const app = source.apps[0];
  assertEqual(app.bundleIdentifier, BUNDLE_ID, "app bundle identifier");
  if (!Array.isArray(app.versions) || app.versions.length !== 1) {
    throw new Error("app.versions must contain exactly one version");
  }

  const entry = app.versions[0];
  assertEqual(entry.version, version, "release version");
  assertEqual(entry.size, ipaAsset.size, "source IPA size");
  assertEqual(
    entry.downloadURL,
    `https://github.com/${repo}/releases/download/${tag}/TuneMetronome.ipa`,
    "source IPA URL",
  );

  const iconURL = `https://github.com/${repo}/releases/download/${tag}/icon.png`;
  assertEqual(source.iconURL, iconURL, "source iconURL");
  assertEqual(source.headerURL, iconURL, "source headerURL");
  assertEqual(app.iconURL, iconURL, "app iconURL");

  if (sourceAsset.size <= 0) {
    throw new Error("source.json asset has an invalid size");
  }
}

async function verify() {
  const { tag, repo, waitSeconds, allowNotLatest } = parseArgs(process.argv.slice(2));

  process.stdout.write(`Verifying ${repo} release ${tag}\n`);
  await waitForLatest(repo, tag, waitSeconds, allowNotLatest);

  const release = await getJson(
    `https://api.github.com/repos/${repo}/releases/tags/${encodeURIComponent(tag)}`,
    "fetch tagged release",
  );
  const assets = validateReleaseMetadata(release, tag);
  const ipaAsset = assets.get("TuneMetronome.ipa");
  const iconAsset = assets.get("icon.png");
  const sourceAsset = assets.get("source.json");
  process.stdout.write("[ok] release is published, Latest, and has the three required assets\n");

  const sourceBytes = await getBytes(sourceAsset.browser_download_url, "download source.json");
  assertEqual(sourceBytes.length, sourceAsset.size, "source.json asset size");
  let source;
  try {
    source = JSON.parse(sourceBytes.toString("utf8"));
  } catch (error) {
    throw new Error(`source.json is not valid JSON: ${error.message}`);
  }
  validateSource(source, { tag, repo, ipaAsset, iconAsset, sourceAsset });
  process.stdout.write("[ok] source.json metadata matches the release\n");

  const latestSourceBytes = await getBytes(
    `https://github.com/${repo}/releases/latest/download/source.json`,
    "download Latest source URL",
  );
  assertEqual(
    latestSourceBytes.toString("utf8"),
    sourceBytes.toString("utf8"),
    "Latest source URL content",
  );
  process.stdout.write("[ok] public Latest source URL matches the release asset\n");

  const ipaBytes = await getBytes(ipaAsset.browser_download_url, "download IPA");
  assertEqual(ipaBytes.length, ipaAsset.size, "downloaded IPA size");
  const ipaDigest = `sha256:${createHash("sha256").update(ipaBytes).digest("hex")}`;
  assertEqual(ipaDigest, ipaAsset.digest, "downloaded IPA digest");
  process.stdout.write(`[ok] IPA downloaded and verified (${ipaBytes.length} bytes)\n`);

  const iconBytes = await getBytes(iconAsset.browser_download_url, "download icon");
  assertEqual(iconBytes.length, iconAsset.size, "downloaded icon size");
  const iconDigest = `sha256:${createHash("sha256").update(iconBytes).digest("hex")}`;
  assertEqual(iconDigest, iconAsset.digest, "downloaded icon digest");
  process.stdout.write(`[ok] icon downloaded and verified (${iconBytes.length} bytes)\n`);

  process.stdout.write(`Release ${tag} is ready for SideStore.\n`);
}

verify().catch((error) => {
  process.stderr.write(`release verification failed: ${error.message}\n`);
  process.exitCode = 1;
});