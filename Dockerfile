FROM node:20-alpine

WORKDIR /app

# Copy package files and install dependencies
COPY package*.json ./
RUN npm install

# Copy all source files
COPY . .

# Generate Prisma Client
RUN npx prisma generate

# Turn off deleteOutDir so loop doesn't wipe previous builds
RUN sed -i 's/"deleteOutDir": true/"deleteOutDir": false/g' nest-cli.json

# Build all applications dynamically based on nest-cli.json
RUN apk add --no-cache jq && \
    jq -r '.projects | to_entries[] | select(.value.type == "application") | .key' nest-cli.json | xargs -I {} npx nest build {}
