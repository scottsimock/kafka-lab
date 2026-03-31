import type { NextConfig } from 'next';

const nextConfig: NextConfig = {
  output: 'standalone',
  compress: false, // Function App handles compression
  webpack: (config, { isServer }) => {
    if (isServer) {
      // Mark the Kafka native module as external to prevent bundling
      config.externals = config.externals || [];
      config.externals.push({
        '@confluentinc/kafka-javascript': 'commonjs @confluentinc/kafka-javascript',
      });
    }
    return config;
  },
};

export default nextConfig;
