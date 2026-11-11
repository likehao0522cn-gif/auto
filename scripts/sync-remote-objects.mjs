#!/usr/bin/env node
// Sync git objects that exist only on the remote into the local object store.
//
// Pushing through the GitHub API creates blobs, trees and commits on the
// server without writing them locally, so 'git status' later fails with
// "bad tree object HEAD". This script walks the remote tree for a ref and
// writes every missing object into the local repository.
//
// Usage: node scripts/sync-remote-objects.mjs <owner/repo> <ref> <token>
import { execFileSync } from "node:child_process";

const [repo, ref, token] = process.argv.slice(2);
if (!repo || !ref || !token) {
  console.error("usage: sync-remote-objects.mjs <owner/repo> <ref> <token>");
  process.exit(1);
}

const git = (args, input) =>
  execFileSync("git", args, { input, encoding: input ? undefined : "utf8" });

const hasObject = (sha) => {
  try {
    git(["cat-file", "-e", sha]);
    return true;
  } catch {
    return false;
  }
};

async function api(path) {
  const res = await fetch("https://api.github.com" + path, {
    headers: {
      "User-Agent": "sync-remote-objects",
      Authorization: "token " + token,
      Accept: "application/vnd.github+json"
    }
  });
  const text = await res.text();
  if (!res.ok) throw new Error(path + " -> " + res.status + " " + text.slice(0, 200));
  return JSON.parse(text);
}

async function writeBlob(sha) {
  if (hasObject(sha)) return;
  const blob = await api(`/repos/${repo}/git/blobs/${sha}`);
  const content = Buffer.from(blob.content, blob.encoding === "base64" ? "base64" : "utf8");
  git(["hash-object", "-w", "-t", "blob", "--stdin"], content);
}

async function writeTree(sha) {
  if (hasObject(sha)) return;
  const tree = await api(`/repos/${repo}/git/trees/${sha}`);
  const lines = [];
  for (const entry of tree.tree) {
    if (entry.type === "blob") await writeBlob(entry.sha);
    else if (entry.type === "tree") await writeTree(entry.sha);
    lines.push(`${entry.mode} ${entry.type} ${entry.sha}\t${entry.path}`);
  }
  git(["mktree"], lines.join("\n") + "\n");
}

const refData = await api(`/repos/${repo}/git/ref/${ref}`);
const commitSha = refData.object.sha;

// Always make sure the commit's tree is complete. The commit object itself may
// already exist locally (it was rebuilt by hand after an API push) while its
// tree objects were never written, which is exactly the state that makes
// "git status" fail with "bad tree object HEAD".
const commit = await api(`/repos/${repo}/git/commits/${commitSha}`);
await writeTree(commit.tree.sha);
console.log("synced", commitSha);
