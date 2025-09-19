FROM node:18-alpine

WORKDIR /app

# Copy package files
COPY package*.json ./

# Install dependencies (fallback to install to avoid lockfile friction in CI)
ENV npm_config_legacy_peer_deps=true
RUN npm install --only=production --no-audit --no-fund

# Copy application code
COPY . .

# Create non-root user
RUN addgroup -g 1001 -S nodejs
RUN adduser -S nodejs -u 1001

# Change ownership of the app directory
RUN chown -R nodejs:nodejs /app
USER nodejs

# Expose port
EXPOSE 3001

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD node -e "require('http').get('http://localhost:3001/test', (res) => { process.exit(res.statusCode === 200 ? 0 : 1) })"

# Start the application using node directly (no nodemon needed for production)
CMD ["node", "index.js"]
