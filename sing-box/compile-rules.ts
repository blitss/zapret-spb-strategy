#!/usr/bin/env bun

import { parse } from "yaml";
import { $ } from "bun";
import { join, dirname } from "path";

interface Rule {
  domains?: string;
  subnets?: string;
  outbound: string;
}

interface Config {
  rules: Rule[];
}

interface OutboundData {
  domains: string[];
  subnets: string[];
}

const readLines = async (source: string, baseDir: string): Promise<string[]> => {
  let content: string;

  if (source.startsWith("http://") || source.startsWith("https://")) {
    console.log(`  Fetching: ${source}`);
    const response = await fetch(source);
    if (!response.ok) {
      throw new Error(`Failed to fetch ${source}: ${response.statusText}`);
    }
    content = await response.text();
  } else {
    const filePath = join(baseDir, source);
    console.log(`  Reading: ${filePath}`);
    const file = Bun.file(filePath);
    content = await file.text();
  }

  return content
    .split("\n")
    .map((line) => line.trim())
    .filter((line) => line && !line.startsWith("#"));
};

const generateSrs = async (
  outboundName: string,
  data: OutboundData,
  outputDir: string
): Promise<void> => {
  const jsonDir = join(outputDir, "json");
  const srsDir = join(outputDir, "srs");

  await Bun.write(join(jsonDir, ".gitkeep"), "");
  await Bun.write(join(srsDir, ".gitkeep"), "");

  const rules: Record<string, string[]>[] = [];

  if (data.domains.length > 0) {
    rules.push({ domain_suffix: data.domains });
  }

  if (data.subnets.length > 0) {
    rules.push({ ip_cidr: data.subnets });
  }

  if (rules.length === 0) {
    console.log(`  Skipping ${outboundName}: no rules`);
    return;
  }

  const ruleSet = {
    version: 3,
    rules,
  };

  const jsonPath = join(jsonDir, `${outboundName}-rule.json`);
  const srsPath = join(srsDir, `${outboundName}-rule.srs`);

  await Bun.write(jsonPath, JSON.stringify(ruleSet, null, 2));
  console.log(`  Generated JSON: ${jsonPath}`);

  try {
    await $`sing-box rule-set compile ${jsonPath} -o ${srsPath}`.quiet();
    console.log(`  Compiled SRS: ${srsPath}`);
  } catch (error) {
    console.error(`  Failed to compile ${jsonPath}:`, error);
  }
};

const main = async () => {
  const configPath = join(import.meta.dir, "config.yaml");
  const outputDir = import.meta.dir;

  console.log("Reading config:", configPath);
  const configFile = Bun.file(configPath);
  const configContent = await configFile.text();
  const config = parse(configContent) as Config;

  const outbounds = new Map<string, OutboundData>();

  for (const rule of config.rules) {
    if (!outbounds.has(rule.outbound)) {
      outbounds.set(rule.outbound, { domains: [], subnets: [] });
    }

    const data = outbounds.get(rule.outbound)!;

    if (rule.domains) {
      const domains = await readLines(rule.domains, import.meta.dir);
      data.domains.push(...domains);
    }

    if (rule.subnets) {
      const subnets = await readLines(rule.subnets, import.meta.dir);
      data.subnets.push(...subnets);
    }
  }

  console.log("\nGenerating rule sets...");
  for (const [outbound, data] of outbounds) {
    console.log(`\nOutbound: ${outbound}`);
    console.log(`  Domains: ${data.domains.length}, Subnets: ${data.subnets.length}`);

    // Deduplicate
    data.domains = [...new Set(data.domains)];
    data.subnets = [...new Set(data.subnets)];

    await generateSrs(outbound, data, outputDir);
  }

  console.log("\nDone!");
};

main().catch(console.error);
