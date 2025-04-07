# Use the official Rust image as the base image
FROM rust:1.77-slim AS builder

# Set the working directory inside the container
WORKDIR /usr/src/aichat

# Install necessary dependencies
RUN apt-get update && apt-get install -y \
    git \
    && rm -rf /var/lib/apt/lists/*

# Clone the repository from GitHub
RUN git clone https://github.com/sigoden/aichat.git .

# Build the project
RUN cargo build --release

# Final stage: Create a lightweight runtime image
FROM debian:bookworm-slim

# Set the working directory
WORKDIR /app

# Copy the compiled binary from the builder stage
COPY --from=builder /usr/src/aichat/target/release/aichat /app/aichat

# Ensure the binary is executable
RUN chmod +x /app/aichat

# Set environment variables (optional, adjust as needed)
ENV PATH="/app:${PATH}"

# Command to run the aichat CLI
ENTRYPOINT ["/app/aichat"]
CMD ["--help"]
