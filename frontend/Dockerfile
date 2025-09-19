# Multi-stage build for React frontend
FROM node:18-alpine as build

WORKDIR /app

# Accept build arguments
ARG REACT_APP_API_DOMAIN
ARG REACT_APP_WEBSITE_DOMAIN

# Set environment variables for build
ENV REACT_APP_API_DOMAIN=$REACT_APP_API_DOMAIN
ENV REACT_APP_WEBSITE_DOMAIN=$REACT_APP_WEBSITE_DOMAIN

# Copy package files
COPY package*.json ./

# Install dependencies (use install for broader compatibility in CI/build containers)
ENV npm_config_legacy_peer_deps=true
RUN npm install --no-audit --no-fund

# Copy source code
COPY . .

RUN echo "REACT_APP_API_DOMAIN=$REACT_APP_API_DOMAIN" && \
    echo "REACT_APP_WEBSITE_DOMAIN=$REACT_APP_WEBSITE_DOMAIN"

# Build the application
ENV NODE_OPTIONS=--max_old_space_size=1024
RUN npm run build

# Production stage with nginx
FROM nginx:alpine

# Copy built files from build stage
COPY --from=build /app/build /usr/share/nginx/html

# Copy nginx configuration
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Expose port
EXPOSE 3000

# Start nginx
CMD ["nginx", "-g", "daemon off;"]
