#!/usr/bin/env bun

const DIR = "zapret/ipset"

const download = async (url: string, file: string) => {
  console.log(`Fetching ${file}...`)
  const res = await fetch(url)
  await Bun.write(`${DIR}/${file}`, res)
}

const dropComments = (text: string) =>
  text
    .split("\n")
    .filter((l) => l && !l.startsWith("#"))
    .join("\n")


await download(
  "https://raw.githubusercontent.com/123jjck/cdn-ip-ranges/main/all/all_plain_ipv4.txt",
  "cust2.txt"
)

await download(
  "https://raw.githubusercontent.com/123jjck/cdn-ip-ranges/refs/heads/main/akamai/akamai_plain_ipv4.txt",
  "akamai.txt"
)

await download(
  "https://raw.githubusercontent.com/IndeecFOX/zapret4rocket/master/extra_strats/TCP/RKN/List.txt",
  "zapret-hosts-user.txt"
)

const waRes = await fetch(
  "https://raw.githubusercontent.com/HybridNetworks/whatsapp-cidr/main/WhatsApp/whatsapp_cidr_ipv4.txt"
)
await Bun.write(`${DIR}/wa-ipset.txt`, dropComments(await waRes.text()))
console.log("Fetching wa-ipset.txt...")

console.log("Done!")

export { }

