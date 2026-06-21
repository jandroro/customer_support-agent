/** @type {import('next').NextConfig} */
const nextConfig = {
  // Produces a minimal self-contained server bundle (.next/standalone) so the
  // Docker image doesn't need to ship node_modules or run `npm install`.
  output: "standalone",
};

module.exports = nextConfig;
