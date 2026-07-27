# Stage 1: Build binary using lightweight Go Alpine image
FROM golang:1.24-alpine AS builder

WORKDIR /app

# Cache dependencies
COPY go.mod go.sum ./
RUN go mod download

# Copy source code
COPY . .

# Build lightweight, statically linked binary stripped of debug information (-s -w)
RUN CGO_ENABLED=0 GOOS=linux go build -ldflags="-s -w" -o server main.go

# Stage 2: Minimal runtime image using scratch (~10-15MB final image size)
FROM scratch

# Copy CA certificates for HTTPS requests if needed
COPY --from=builder /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/

# Copy static binary from builder stage
COPY --from=builder /app/server /server

# Run as non-root user (nobody) for enhanced security
USER 65534:65534

# Expose port 8080
EXPOSE 8080

# Launch server
ENTRYPOINT ["/server"]
