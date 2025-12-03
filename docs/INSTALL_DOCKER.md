# Installing Docker

Docker is required to build container images for deployment. Here are installation instructions for different platforms.

## macOS

### Option 1: Docker Desktop (Recommended)

1. **Download Docker Desktop:**
   - Visit: https://www.docker.com/products/docker-desktop/
   - Click "Download for Mac"
   - Choose the version for your Mac (Intel or Apple Silicon)

2. **Install:**
   - Open the downloaded `.dmg` file
   - Drag Docker to Applications folder
   - Open Docker from Applications
   - Follow the setup wizard

3. **Verify installation:**
   ```bash
   docker --version
   docker run hello-world
   ```

### Option 2: Homebrew

```bash
brew install --cask docker
```

Then open Docker Desktop from Applications.

## Alternative: Deploy Without Local Docker

If you don't want to install Docker locally, you can use **Cloud Build** which builds in the cloud!

See `DEPLOY_WITHOUT_DOCKER.md` for instructions.

## Verify Docker is Working

After installation, verify:

```bash
docker --version
# Should show: Docker version 20.x.x or higher

docker ps
# Should show running containers (may be empty, that's OK)
```

## Troubleshooting

### Docker daemon not running
- Make sure Docker Desktop is running (check the menu bar)
- On macOS, Docker Desktop must be running for `docker` commands to work

### Permission denied
- Docker Desktop should handle permissions automatically
- If issues persist, you may need to add your user to the docker group (Linux) or restart Docker Desktop (macOS)

## Next Steps

Once Docker is installed:
1. ✅ Verify with `docker --version`
2. ✅ Run `./deploy.sh` again
3. ✅ Or use Cloud Build (no local Docker needed)

