# GenieACS Docker Deployment

![Docker](https://img.shields.io/badge/Docker-%E2%9C%93-blue?style=flat-square)
![MongoDB](https://img.shields.io/badge/MongoDB-8.0-green?style=flat-square)
![GenieACS](https://img.shields.io/badge/GenieACS-1.2.13-orange?style=flat-square)
![Multi-Arch](https://img.shields.io/badge/multi--arch-amd64%2Carm64%2Carmv7-lightgrey?style=flat-square)

Docker container for deployment GenieACS v1.2.13 with MongoDB 8.0, optimized for production use with security hardening, health checks, and log management.

## 📋 Features
- ✅ GenieACS v1.2.13 (CWMP, NBI, FS, UI)
- ✅ MongoDB 8.0 with health check
- ✅ Multi-architecture support (amd64, arm64, arm/v7)
- ✅ Security hardened image
- ✅ Auto-restart and health monitoring
- ✅ Log rotation support
- ✅ Data persistence with Docker volumes
- ✅ Environment variables configuration
- ✅ Backup and restore functionality
- ✅ Comprehensive management via Makefile

## 🚀 Quick Start

### Prerequisites
- Docker & Docker Compose
- Git
- Make (optional but recommended)

### 1. Clone and Setup
```bash
# Clone the repository (if applicable)
git clone <your-repo-url>
cd genieacs-docker

# Setup configuration files
make setup
```

This command will create:
- `genieacs.logrotate` - Configuration for log rotation
- `config/` directory - For GenieACS configuration files
- `ext/` directory - For extensions GenieACS
- `backups/` directory - For MongoDB backups

### 2. Full Installation & Run
```bash
# Build Docker image
make build

# Start all services
make up

# Check service status
make status

# Test service health
make test

# Open http://localhost:3000
# Default login: admin / admin
```

## 📁 Structure Project
```
.
├── Dockerfile              # Docker build configuration
├── Makefile               # Build and management commands
├── docker-compose.yml     # Service orchestration
├── genieacs.logrotate    # Log rotation config
├── config/               # Configuration directory (created by make setup)
├── ext/                  # GenieACS extensions directory (created by make setup)
└── backups/              # MongoDB backups directory (created by make setup)
```

## 🛠️ Management Commands

### Build & Deployment
```bash
make setup        # Setup configuration files
make build        # Build image for current architecture
make buildx       # Build multi-platform image
make buildx-push  # Build and push multi-platform image
make push         # Push image to registry
make up           # Start services in background
make down         # Stop and remove services
make logs         # View real-time logs
```

### Maintenance & Monitoring
```bash
make status       # Check service status
make test         # Test service health
make ps           # Show running processes
make restart      # Restart services
make clean        # Cleanup resources
make prune        # Prune unused Docker resources
make scan         # Scan image for vulnerabilities
make verify-deps  # Verify dependency versions
```

### Database & Operations
```bash
make shell-mongo    # Access MongoDB shell
make shell-genieacs # Access GenieACS container shell
make backup         # Backup MongoDB database
make restore FILE=backups/backup_20231201_120000.gz  # Restore from backup
```

### Development & Debugging
```bash
make secure-build  # Build with security verification
make stats         # Show container resource usage
make resources     # Show container resource limits
```

## ⚙️ Configuration

### Environment Variables
**GenieACS Service**:
```yaml
GENIEACS_UI_JWT_SECRET: kmzway87aa  # Change this in production!
GENIEACS_MONGODB_CONNECTION_URL: mongodb://mongo:27017/genieacs
NODE_ENV: production
```

### Port Mapping
| Service | Port | Protocol | Description              |
|---------|------|----------|--------------------------|
| CWMP    | 7547 | TCP      | TR-069/CPE Management    |
| NBI     | 7557 | TCP      | Northbound Interface     |
| FS      | 7567 | TCP      | File Server              |
| UI      | 3000 | TCP      | Web Interface            |

## 🔐 Security Features
- Non-root user execution
- Automated security updates
- Integrated vulnerability scanning
- Minimal package installation
- Log rotation and management
- Health check monitoring
- JWT secret configuration

## 🐳 Docker Images
- **Base Image**: `debian:stable-slim`
- **Node.js Version**: LTS (from `node:lts-slim`)
- **MongoDB Version**: 8.0
- **Image Tags**:
    - `cepatkilatteknologi/genieacs:v1.2.13`
    - `cepatkilatteknologi/genieacs:latest`

## 📊 Monitoring & Health Checks

MongoDB: Checks database connectivity every 10 seconds

GenieACS: Checks UI accessibility every 30 seconds

### Health Checks
**Both containers include health checks:**
- MongoDB: Checks database connectivity every 10 seconds
- GenieACS: Checks UI accessibility every 30 seconds

**Manual Health Testing**
```bash
# Test MongoDB connection
docker exec mongo-genieacs mongosh --eval "db.adminCommand('ping')"

# Test GenieACS UI health
curl -f http://localhost:3000/

# Test GenieACS CWMP endpoint
curl -f http://localhost:7547/
```
**Log Management**
```bash
# View all logs in real-time
make logs

# View specific container logs
docker logs mongo-genieacs -f
docker logs genieacs -f

# Check log files inside container
docker exec genieacs ls -la /var/log/genieacs/
```


## 🗂️ Volumes & Data Persistence
| Volume                  | Description                   | Location            |
|-------------------------|-------------------------------|---------------------|
| genieacs-mongo-data     | MongoDB data storage          | /data/db            |
| genieacs-mongo-configdb | MongoDB config storage        | /data/configdb      |
| genieacs-app-data       | GenieACS application data     | /opt/genieacs       |
| genieacs-logs           | Application logs              | /var/log/genieacs   |

## 🔧 Troubleshooting

### Common Issues & Solutions
**Port already in use**:
```bash
# Check port usage
sudo lsof -i :3000
sudo lsof -i :7547

# Alternative port solution: modify docker-compose.yml ports mapping
# "3001:3000" # Map host port 3001 to container port 3000
```

**MongoDB connection issues**:
```bash
# Check MongoDB logs
docker logs mongo-genieacs

# Test MongoDB connection
docker exec mongo-genieacs mongosh --eval "db.adminCommand('ping')"
```

**Build failures**:
```bash
# Clean build artifacts and rebuild
make clean
make build
```

**Login issues (username/password)**:
```bash
# Reset admin password (run inside MongoDB container)
docker exec mongo-genieacs mongosh genieacs --eval '
  db.users.updateOne(
    { _id: "admin" },
    { $set: {
      password: "$2a$08$r.j7.zbgR5sBfOqLkqPvE.7b1c9d2e3f4g5h6i7j8k9l0m1n2o3p4q",
      salt: "$2a$08$r.j7.zbgR5sBfOqLkqPvE.",
      roles: ["admin"]
    }},
    { upsert: true }
  )
'
```

### Debug Commands
```bash
# Access GenieACS container shell
make shell-genieacs

# Check supervisor status
supervisorctl status

# Test GenieACS binaries
which genieacs-cwmp
which genieacs-nbi
which genieacs-fs
which genieacs-ui

# Check environment variables
env | grep GENIEACS

# Access MongoDB shell
make shell-mongo

# List databases
show dbs

# Check collections in genieacs database
use genieacs
show collections
```

## 📝 Changelog
### v1.2.13
- Initial GenieACS v1.2.13 release
- MongoDB 8.0 support
- Multi-architecture build support (amd64, arm64, arm/v7)
- Security vulnerability fixes
- Health check integration
- Automated setup process
- Comprehensive Makefile for management
- Backup and restore functionality

## 🚨 Important Notes
- Run `make setup` will overwrite existing config files.
- Default login: username: `admin`, password: `admin`.
- Change `GENIEACS_UI_JWT_SECRET` for production environment.
- Regularly backup your data using make backup
- Monitor disk usage of Docker volumes
- Keep your Docker environment updated


## 🤝 Contributing
1. Fork the project.
2. Create your feature branch (`git checkout -b feature/YourFeature`).
3. Commit your changes (`git commit -m 'Add YourFeature'`).
4. Push to the branch (`git push origin feature/YourFeature`).
5. Create a Pull Request.

## 📄 License
This project is licensed under the MIT License - see the [LICENSE](https://github.com/Cepat-Kilat-Teknologi/genieacs-docker/blob/main/LICENSE) file for details.

## 🙏 Acknowledgments
- [GenieACS](https://github.com/genieacs/genieacs) - Open source ACS server
- [Docker](https://www.docker.com/) - Container platform
- [MongoDB](https://www.mongodb.com/) - Database solution

## 📞 Support
For support, please contact:
- **Email**: info@ckt.co.id
- **Issues**: [GitHub Issues page](https://github.com/Cepat-Kilat-Teknologi/genieacs-docker/issues)

⚠️ **Important**: Always ensure to keep your Docker images and containers updated to the latest versions for security and performance improvements.

⚠️ **Note**: This deployment is designed for production use but should be thoroughly tested in your environment before deployment. Always ensure you have proper backups of your MongoDB data.
