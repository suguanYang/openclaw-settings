#!/usr/bin/env node

import process from 'node:process';

import { Client } from '@modelcontextprotocol/sdk/client/index.js';
import { StdioClientTransport } from '@modelcontextprotocol/sdk/client/stdio.js';
import { StreamableHTTPClientTransport } from '@modelcontextprotocol/sdk/client/streamableHttp.js';

const DEFAULT_MCP_COMMAND = 'uvx logfire-mcp@latest';
const DEFAULT_HTTP_TIMEOUT_SECONDS = 30;
const DEFAULT_USER_AGENT = 'openclaw-logfire-alert-poller/1.0';

function main() {
  return run().catch((error) => {
    const message = error instanceof Error ? error.message : String(error);
    process.stderr.write(`${message}\n`);
    process.exitCode = 1;
  });
}

async function run() {
  const args = parseArgs(process.argv.slice(2));
  const transportMode = resolveTransport(
    process.env.LOGFIRE_MCP_TRANSPORT ?? 'auto',
    process.env.LOGFIRE_MCP_ENDPOINT ?? '',
  );
  const client = new Client({
    name: 'oracle-logfire-alert-poller',
    version: '1.0.0',
  });
  const transport = buildTransport(transportMode);

  try {
    await client.connect(transport);
    const listToolsResult = await client.listTools();
    const toolNames = new Set(
      (listToolsResult.tools ?? [])
        .map((tool) => String(tool.name ?? '').trim())
        .filter(Boolean),
    );

    let result;
    if (toolNames.has('query_run')) {
      result = await client.callTool({
        name: 'query_run',
        arguments: {
          project: args.project || undefined,
          query: args.query,
          age: args.ageMinutes,
        },
      });
    } else if (toolNames.has('arbitrary_query')) {
      result = await client.callTool({
        name: 'arbitrary_query',
        arguments: {
          query: args.query,
          age: `${args.ageMinutes}m`,
        },
      });
    } else {
      const known = [...toolNames].sort().join(', ') || '(none)';
      throw new Error(
        `Logfire MCP server does not expose a supported query tool. Available tools: ${known}`,
      );
    }

    if (result.isError) {
      throw new Error(extractToolErrorText(result));
    }

    process.stdout.write(`${JSON.stringify(result)}\n`);
  } finally {
    if (
      'terminateSession' in transport &&
      typeof transport.terminateSession === 'function'
    ) {
      await transport.terminateSession().catch(() => {});
    }
    await transport.close().catch(() => {});
  }
}

function parseArgs(argv) {
  let query = '';
  let project = '';
  let ageMinutes = 0;

  for (let index = 0; index < argv.length; index += 1) {
    const arg = argv[index];
    if (arg === '--query') {
      query = argv[index + 1] ?? '';
      index += 1;
      continue;
    }
    if (arg === '--project') {
      project = argv[index + 1] ?? '';
      index += 1;
      continue;
    }
    if (arg === '--age-minutes') {
      ageMinutes = parsePositiveInt(argv[index + 1] ?? '', '--age-minutes');
      index += 1;
      continue;
    }
    throw new Error(`unknown argument: ${arg}`);
  }

  if (!query.trim()) {
    throw new Error('missing required argument: --query');
  }
  if (ageMinutes <= 0) {
    throw new Error('missing required argument: --age-minutes');
  }

  return {
    query: query.trim(),
    project: project.trim(),
    ageMinutes,
  };
}

function parsePositiveInt(rawValue, label) {
  const value = Number.parseInt(String(rawValue).trim(), 10);
  if (!Number.isFinite(value) || value <= 0) {
    throw new Error(`${label} must be a positive integer`);
  }
  return value;
}

function resolveTransport(rawTransport, endpoint) {
  const normalized = String(rawTransport).trim().toLowerCase() || 'auto';
  if (normalized === 'auto') {
    return endpoint.trim() ? 'http' : 'stdio';
  }
  if (normalized !== 'http' && normalized !== 'stdio') {
    throw new Error('LOGFIRE_MCP_TRANSPORT must be one of: auto, http, stdio');
  }
  return normalized;
}

function buildTransport(transportMode) {
  if (transportMode === 'http') {
    const endpoint = requireEnv('LOGFIRE_MCP_ENDPOINT');
    const readToken = requireEnv('LOGFIRE_READ_TOKEN');
    const timeoutMs =
      parsePositiveInt(
        process.env.LOGFIRE_MCP_HTTP_TIMEOUT_SECONDS ??
          String(DEFAULT_HTTP_TIMEOUT_SECONDS),
        'LOGFIRE_MCP_HTTP_TIMEOUT_SECONDS',
      ) * 1000;
    const userAgent =
      process.env.LOGFIRE_MCP_USER_AGENT?.trim() || DEFAULT_USER_AGENT;

    return new StreamableHTTPClientTransport(new URL(endpoint), {
      requestInit: {
        headers: {
          Authorization: `Bearer ${readToken}`,
          'User-Agent': userAgent,
        },
      },
      fetch: (input, init) =>
        fetch(input, {
          ...init,
          signal: AbortSignal.timeout(timeoutMs),
        }),
    });
  }

  const mcpCommand = process.env.LOGFIRE_MCP_COMMAND?.trim() || DEFAULT_MCP_COMMAND;
  if (!mcpCommand) {
    throw new Error('LOGFIRE_MCP_COMMAND resolved to an empty command');
  }
  return new StdioClientTransport({
    command: '/bin/sh',
    args: ['-lc', mcpCommand],
    env: {
      ...process.env,
      LOGFIRE_READ_TOKEN: requireEnv('LOGFIRE_READ_TOKEN'),
    },
    stderr: 'pipe',
  });
}

function requireEnv(name) {
  const value = process.env[name]?.trim() ?? '';
  if (!value) {
    throw new Error(`missing required environment variable: ${name}`);
  }
  return value;
}

function extractToolErrorText(result) {
  if (!Array.isArray(result.content)) {
    return 'unknown MCP tool error';
  }
  const parts = result.content
    .filter((item) => item?.type === 'text' && typeof item.text === 'string')
    .map((item) => item.text.trim())
    .filter(Boolean);
  if (parts.length > 0) {
    return parts.join(' ');
  }
  return 'unknown MCP tool error';
}

await main();
