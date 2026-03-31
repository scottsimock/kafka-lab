import type { NextConfig } from 'next';

const nextConfig: NextConfig = {
  output: 'standalone',
  compress: false, // Function App handles compression
};

export default nextConfig;
