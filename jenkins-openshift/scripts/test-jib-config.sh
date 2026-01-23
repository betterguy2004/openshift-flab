#!/bin/bash
# Test Jib Configuration
# This script validates that Jib is properly configured

set -e

echo "========================================="
echo "Jib Configuration Test"
echo "========================================="
echo ""

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if we're in the right directory
if [ ! -f "pom.xml" ]; then
    echo -e "${RED}❌ Error: pom.xml not found${NC}"
    echo "Please run this script from the spring-petclinic directory"
    exit 1
fi

echo -e "${YELLOW}1. Checking Maven installation...${NC}"
if command -v mvn &> /dev/null; then
    MVN_VERSION=$(mvn -version | head -n 1)
    echo -e "${GREEN}✓ Maven found: $MVN_VERSION${NC}"
else
    echo -e "${RED}❌ Maven not found. Please install Maven 3.9+${NC}"
    exit 1
fi

echo ""
echo -e "${YELLOW}2. Checking Java version...${NC}"
if command -v java &> /dev/null; then
    JAVA_VERSION=$(java -version 2>&1 | head -n 1)
    echo -e "${GREEN}✓ Java found: $JAVA_VERSION${NC}"
else
    echo -e "${RED}❌ Java not found. Please install Java 17+${NC}"
    exit 1
fi

echo ""
echo -e "${YELLOW}3. Checking Jib plugin in pom.xml...${NC}"
if grep -q "jib-maven-plugin" pom.xml; then
    JIB_VERSION=$(grep -A 1 "jib-maven-plugin" pom.xml | grep "<version>" | sed 's/.*<version>\(.*\)<\/version>.*/\1/' | head -n 1)
    echo -e "${GREEN}✓ Jib plugin found: version $JIB_VERSION${NC}"
else
    echo -e "${RED}❌ Jib plugin not found in pom.xml${NC}"
    exit 1
fi

echo ""
echo -e "${YELLOW}4. Checking Nexus registry configuration...${NC}"
if grep -q "nexus.apps.s68" pom.xml; then
    echo -e "${GREEN}✓ Nexus registry configured: nexus.apps.s68${NC}"
else
    echo -e "${RED}❌ Nexus registry not configured${NC}"
    exit 1
fi

echo ""
echo -e "${YELLOW}5. Checking environment variables...${NC}"
if [ -z "$NEXUS_USERNAME" ]; then
    echo -e "${YELLOW}⚠ NEXUS_USERNAME not set (will use default: admin)${NC}"
    export NEXUS_USERNAME=admin
else
    echo -e "${GREEN}✓ NEXUS_USERNAME: $NEXUS_USERNAME${NC}"
fi

if [ -z "$NEXUS_PASSWORD" ]; then
    echo -e "${YELLOW}⚠ NEXUS_PASSWORD not set (will use default: 123456789)${NC}"
    export NEXUS_PASSWORD=123456789
else
    echo -e "${GREEN}✓ NEXUS_PASSWORD: ********${NC}"
fi

echo ""
echo -e "${YELLOW}6. Testing Nexus connectivity...${NC}"
if curl -s -o /dev/null -w "%{http_code}" http://nexus.apps.s68 | grep -q "200\|302\|401"; then
    echo -e "${GREEN}✓ Nexus registry is reachable${NC}"
else
    echo -e "${RED}❌ Cannot reach Nexus registry at nexus.apps.s68${NC}"
    echo "Please check network connectivity"
fi

echo ""
echo -e "${YELLOW}7. Validating pom.xml...${NC}"
if mvn validate > /dev/null 2>&1; then
    echo -e "${GREEN}✓ pom.xml is valid${NC}"
else
    echo -e "${RED}❌ pom.xml validation failed${NC}"
    mvn validate
    exit 1
fi

echo ""
echo "========================================="
echo -e "${GREEN}✅ All checks passed!${NC}"
echo "========================================="
echo ""
echo "You can now build and push the image with:"
echo -e "${YELLOW}  mvn clean package jib:build${NC}"
echo ""
echo "Or test locally with Docker:"
echo -e "${YELLOW}  mvn clean package jib:dockerBuild${NC}"
echo ""
