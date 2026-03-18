import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  async redirects() {
    return [
      {
        source: '/:path*',
        has: [{ type: 'host', value: 'home.condomeet.app.br' }],
        destination: 'https://condomeet.app.br/login',
        permanent: true,
      },
    ]
  },
};

export default nextConfig;
